use std::sync::Arc;

use axum::extract::{Path, State};
use axum::http::{HeaderMap, StatusCode};
use axum::Json;
use serde::Deserialize;

use crate::auth::extract_auth;
use crate::db::User;
use crate::AppState;

fn err(status: StatusCode, msg: &str) -> (StatusCode, Json<serde_json::Value>) {
    (status, Json(serde_json::json!({ "error": msg })))
}

fn require_admin(
    headers: &HeaderMap,
    state: &AppState,
) -> Result<crate::auth::Claims, (StatusCode, Json<serde_json::Value>)> {
    let claims = extract_auth(headers, state)?;
    if claims.role != "admin" {
        return Err(err(StatusCode::FORBIDDEN, "Acesso restrito a administradores"));
    }
    Ok(claims)
}

pub async fn list_users(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<Vec<User>>, (StatusCode, Json<serde_json::Value>)> {
    require_admin(&headers, &state)?;

    let users = state
        .db
        .list_users()
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?;

    Ok(Json(users))
}

#[derive(Deserialize)]
pub struct CreateUserRequest {
    pub username: String,
    pub password: String,
    pub display_name: Option<String>,
    pub role: Option<String>,
}

pub async fn create_user(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<CreateUserRequest>,
) -> Result<(StatusCode, Json<User>), (StatusCode, Json<serde_json::Value>)> {
    require_admin(&headers, &state)?;

    if body.username.trim().is_empty() || body.password.is_empty() {
        return Err(err(StatusCode::BAD_REQUEST, "Usuário e senha são obrigatórios"));
    }

    let role = body.role.as_deref().unwrap_or("user");
    if role != "admin" && role != "user" {
        return Err(err(StatusCode::BAD_REQUEST, "Role deve ser 'admin' ou 'user'"));
    }

    let display_name = body.display_name.as_deref().unwrap_or("");

    let user = state
        .db
        .create_user(&body.username, &body.password, display_name, role)
        .map_err(|e| {
            let msg = e.to_string();
            if msg.contains("UNIQUE") {
                err(StatusCode::CONFLICT, "Usuário já existe")
            } else {
                err(StatusCode::INTERNAL_SERVER_ERROR, "Erro ao criar usuário")
            }
        })?;

    Ok((StatusCode::CREATED, Json(user)))
}

pub async fn get_user(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<User>, (StatusCode, Json<serde_json::Value>)> {
    require_admin(&headers, &state)?;

    let user = state
        .db
        .get_user_by_id(&id)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro interno"))?
        .ok_or_else(|| err(StatusCode::NOT_FOUND, "Usuário não encontrado"))?;

    Ok(Json(user.to_public()))
}

#[derive(Deserialize)]
pub struct UpdateUserRequest {
    pub display_name: Option<String>,
    pub role: Option<String>,
    pub password: Option<String>,
}

pub async fn update_user(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(id): Path<String>,
    Json(body): Json<UpdateUserRequest>,
) -> Result<Json<User>, (StatusCode, Json<serde_json::Value>)> {
    require_admin(&headers, &state)?;

    if let Some(ref r) = body.role {
        if r != "admin" && r != "user" {
            return Err(err(StatusCode::BAD_REQUEST, "Role deve ser 'admin' ou 'user'"));
        }
    }

    let user = state
        .db
        .update_user(
            &id,
            body.display_name.as_deref(),
            body.role.as_deref(),
            body.password.as_deref(),
        )
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro ao atualizar"))?
        .ok_or_else(|| err(StatusCode::NOT_FOUND, "Usuário não encontrado"))?;

    Ok(Json(user))
}

pub async fn delete_user(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let claims = require_admin(&headers, &state)?;

    if claims.sub == id {
        return Err(err(StatusCode::BAD_REQUEST, "Não é possível excluir o próprio usuário"));
    }

    let deleted = state
        .db
        .delete_user(&id)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Erro ao excluir"))?;

    if !deleted {
        return Err(err(StatusCode::NOT_FOUND, "Usuário não encontrado"));
    }

    Ok(Json(serde_json::json!({ "ok": true })))
}
