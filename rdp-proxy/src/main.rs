use std::net::SocketAddr;
use std::sync::Arc;

use axum::routing::{delete, get, post, put};
use axum::Router;
use tower_http::cors::CorsLayer;
use tracing::info;

mod auth;
mod db;
mod rdp;
mod users;

pub struct AppState {
    pub db: db::Database,
    pub jwt_secret: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "rdp_proxy=info".into()),
        )
        .init();

    let db_path = std::env::var("DB_PATH").unwrap_or_else(|_| "/data/koder.db".to_string());
    let database = db::Database::new(&db_path)?;
    database.initialize()?;

    let jwt_secret = std::env::var("JWT_SECRET")
        .unwrap_or_else(|_| uuid::Uuid::new_v4().to_string());

    let state = Arc::new(AppState {
        db: database,
        jwt_secret,
    });

    let app = Router::new()
        .route("/api/auth/login", post(auth::login))
        .route("/api/auth/me", get(auth::me))
        .route("/api/auth/password", put(auth::change_password))
        .route("/api/users", get(users::list_users))
        .route("/api/users", post(users::create_user))
        .route("/api/users/{id}", get(users::get_user))
        .route("/api/users/{id}", put(users::update_user))
        .route("/api/users/{id}", delete(users::delete_user))
        .route("/rdp-proxy", get(rdp::ws_handler))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let listen_addr: SocketAddr = std::env::var("PROXY_LISTEN")
        .unwrap_or_else(|_| "127.0.0.1:8443".to_string())
        .parse()?;

    info!("koder server listening on {listen_addr}");

    let listener = tokio::net::TcpListener::bind(listen_addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
