package com.nemo.backend.domain.auth.dto;

public record RefreshResponse(String accessToken, String refreshToken, long expiresIn) { }
