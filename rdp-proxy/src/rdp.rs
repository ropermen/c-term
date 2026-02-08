use std::sync::Arc;

use anyhow::{anyhow, Context as _};
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::response::IntoResponse;
use futures_util::{SinkExt, StreamExt};
use ironrdp_rdcleanpath::RDCleanPathPdu;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tracing::{error, info};

use crate::AppState;

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(_state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| async {
        if let Err(e) = handle_rdp_connection(socket).await {
            error!("RDP proxy error: {e:#}");
        }
    })
}

async fn handle_rdp_connection(socket: WebSocket) -> anyhow::Result<()> {
    info!("New RDP WebSocket connection");

    let (mut ws_write, mut ws_read) = socket.split();

    // Step 1: Read the RDCleanPath request (first binary message)
    let request_bytes = loop {
        match ws_read.next().await {
            Some(Ok(Message::Binary(data))) => break data,
            Some(Ok(Message::Ping(data))) => {
                ws_write.send(Message::Pong(data)).await?;
                continue;
            }
            Some(Ok(Message::Close(_))) | None => {
                return Err(anyhow!("Connection closed before RDCleanPath request"));
            }
            Some(Ok(_)) => continue,
            Some(Err(e)) => return Err(anyhow!("WebSocket error: {e}")),
        }
    };

    // Step 2: Parse the RDCleanPath request
    let pdu = RDCleanPathPdu::from_der(&request_bytes)
        .map_err(|e| anyhow!("Failed to parse RDCleanPath PDU: {e}"))?;

    let rdcleanpath = pdu
        .into_enum()
        .map_err(|e| anyhow!("Invalid RDCleanPath PDU: {e}"))?;

    let (destination, x224_request) = match rdcleanpath {
        ironrdp_rdcleanpath::RDCleanPath::Request {
            destination,
            x224_connection_request,
            ..
        } => (destination, x224_connection_request.as_bytes().to_vec()),
        _ => {
            let err_pdu = RDCleanPathPdu::new_general_error();
            let err_bytes = err_pdu
                .to_der()
                .map_err(|e| anyhow!("DER encode error: {e}"))?;
            ws_write.send(Message::Binary(err_bytes)).await?;
            return Err(anyhow!("Expected RDCleanPath Request"));
        }
    };

    info!("RDP destination: {destination}");

    // Step 3: Connect to the RDP server via TCP
    let rdp_stream = TcpStream::connect(&destination)
        .await
        .context(format!("Failed to connect to RDP server at {destination}"))?;

    let server_addr = rdp_stream
        .peer_addr()
        .map(|a| a.to_string())
        .unwrap_or_else(|_| destination.clone());

    // Step 4: X.224 exchange then TLS handshake
    let (mut rdp_read, mut rdp_write) = tokio::io::split(rdp_stream);
    rdp_write
        .write_all(&x224_request)
        .await
        .context("Failed to send X.224 request")?;

    let mut tpkt_header = [0u8; 4];
    rdp_read
        .read_exact(&mut tpkt_header)
        .await
        .context("Failed to read X.224 response header")?;

    let tpkt_len = u16::from_be_bytes([tpkt_header[2], tpkt_header[3]]) as usize;
    let mut x224_response = vec![0u8; tpkt_len];
    x224_response[..4].copy_from_slice(&tpkt_header);
    if tpkt_len > 4 {
        rdp_read
            .read_exact(&mut x224_response[4..])
            .await
            .context("Failed to read X.224 response body")?;
    }

    let rdp_stream = rdp_read.unsplit(rdp_write);
    let tls_connector = native_tls::TlsConnector::builder()
        .danger_accept_invalid_certs(true)
        .danger_accept_invalid_hostnames(true)
        .build()
        .context("Failed to build TLS connector")?;
    let tls_connector = tokio_native_tls::TlsConnector::from(tls_connector);

    let hostname = destination.split(':').next().unwrap_or(&destination);

    let tls_stream = tls_connector
        .connect(hostname, rdp_stream)
        .await
        .context("TLS handshake with RDP server failed")?;

    let server_certs: Vec<Vec<u8>> = tls_stream
        .get_ref()
        .peer_certificate()
        .ok()
        .flatten()
        .map(|cert| vec![cert.to_der().unwrap_or_default()])
        .unwrap_or_default();

    // Step 5: Send RDCleanPath response back to browser
    let response_pdu = RDCleanPathPdu::new_response(server_addr, x224_response, server_certs)
        .map_err(|e| anyhow!("Failed to create RDCleanPath response: {e}"))?;
    let response_bytes = response_pdu
        .to_der()
        .map_err(|e| anyhow!("DER encode error: {e}"))?;
    ws_write
        .send(Message::Binary(response_bytes))
        .await
        .context("Failed to send RDCleanPath response")?;

    info!("RDCleanPath handshake complete for {destination}, starting relay");

    // Step 6: Bidirectional relay (WebSocket <-> TLS TCP)
    let (mut rdp_read, mut rdp_write) = tokio::io::split(tls_stream);

    let ws_to_rdp = async {
        while let Some(msg) = ws_read.next().await {
            match msg {
                Ok(Message::Binary(data)) => {
                    if rdp_write.write_all(&data).await.is_err() {
                        break;
                    }
                }
                Ok(Message::Close(_)) | Err(_) => break,
                _ => continue,
            }
        }
        let _ = rdp_write.shutdown().await;
    };

    let rdp_to_ws = async {
        let mut buf = vec![0u8; 16384];
        loop {
            match rdp_read.read(&mut buf).await {
                Ok(0) => break,
                Ok(n) => {
                    if ws_write
                        .send(Message::Binary(buf[..n].to_vec()))
                        .await
                        .is_err()
                    {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
        let _ = ws_write.close().await;
    };

    tokio::select! {
        _ = ws_to_rdp => {
            info!("WebSocket side closed for {destination}");
        }
        _ = rdp_to_ws => {
            info!("RDP side closed for {destination}");
        }
    }

    info!("Connection to {destination} terminated");
    Ok(())
}
