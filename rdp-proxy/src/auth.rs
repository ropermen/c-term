use std::sync::Arc;

use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::Json;
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};

use crate::db::User;
use crate::AppState;

#[derive(Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,
    pub username: String,
    pub role: String,
    pub exp: usize,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user: User,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

fn err(status: StatusCode, msg: &str) -> (StatusCode, Json<serde_json::Value>) {
    (
        status,
        Json(serde_json::json!({ "error": msg })),
    )
}

pub fn create_token(state: &AppState, user_id: &str, username: &str, role: &str) -> Result<String, jsonwebtoken::errors::Error> {
    let exp = chrono::Utc::now()
        .checked_add_signed(chrono::Duration::hours(24))
        .unwrap()
        .timestamp() as usize;

    let claims = Claims {
        sub: user_id.to_string(),
        username: username.to_string(),
        role: role.to_string(),
        exp,
    };

    jsonwebtoken::encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(state.jwt_secret.as_bytes()),
    )
}

pub fn extract_auth(
    headers: &HeaderMap,
    state: &AppState,
) -> Result<Claims, (StatusCode, Json<serde_json::Value>)> {
    let token = headers
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .ok_or_else(|| err(StatusCode::UNAUTHORIZED, "Token ausente"))?;

    let data = jsonwebtoken::decode::<Claims>(
        token,
        &DecodingKey::from_secret(state.jwt_secret.as_bytes()),
        &Validation::default(),
    )
    .map_err(|_| err(StatusCode::UNAUTHORIZED, "Token inválido ou expirado"))?;

    Ok(data.claims)
}

pub async fn login(
    State(state): State<Arc<AppState>>,
    Json(body): Json<LoginRequest>,
) -> Result<Json<LoginResponse>, (StatusCode, Json<serde_json::Value>)> {
    let user = state
        .db
        .get_user_by_username(&body.username)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?
        .ok_or_else(|| err(StatusCode::UNAUTHORIZED, "Usuário ou senha incorretos"))?;

    let valid = bcrypt::verify(&body.password, &user.password_hash)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?;

    if !valid {
        return Err(err(StatusCode::UNAUTHORIZED, "Usuário ou senha incorretos"));
    }

    let token = create_token(&state, &user.id, &user.username, &user.role)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro ao gerar token"))?;

    Ok(Json(LoginResponse {
        token,
        user: user.to_public(),
    }))
}

pub async fn me(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<User>, (StatusCode, Json<serde_json::Value>)> {
    let claims = extract_auth(&headers, &state)?;

    let user = state
        .db
        .get_user_by_id(&claims.sub)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?
        .ok_or_else(|| err(StatusCode::NOT_FOUND, "Usuário não encontrado"))?;

    Ok(Json(user.to_public()))
}

#[derive(Deserialize)]
pub struct ChangePasswordRequest {
    pub current_password: String,
    pub new_password: String,
}

pub async fn change_password(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<ChangePasswordRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let claims = extract_auth(&headers, &state)?;

    let user = state
        .db
        .get_user_by_id(&claims.sub)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?
        .ok_or_else(|| err(StatusCode::NOT_FOUND, "Usuário não encontrado"))?;

    let valid = bcrypt::verify(&body.current_password, &user.password_hash)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?;

    if !valid {
        return Err(err(StatusCode::BAD_REQUEST, "Senha atual incorreta"));
    }

    state
        .db
        .update_password(&claims.sub, &body.new_password)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro ao atualizar senha"))?;

    Ok(Json(serde_json::json!({ "ok": true })))
}

mod chrono {
    pub struct Utc;

    impl Utc {
        pub fn now() -> DateTime {
            let dur = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap();
            DateTime(dur.as_secs() as i64)
        }
    }

    pub struct DateTime(i64);

    impl DateTime {
        pub fn checked_add_signed(&self, dur: Duration) -> Option<Self> {
            Some(DateTime(self.0 + dur.0))
        }

        pub fn timestamp(&self) -> i64 {
            self.0
        }
    }

    pub struct Duration(i64);

    impl Duration {
        pub fn hours(h: i64) -> Self {
            Duration(h * 3600)
        }
    }
}
