// backend/src/main/java/com/nemo/backend/domain/auth/dto/LogoutRequest.java
package com.nemo.backend.domain.auth.dto;

import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class LogoutRequest {
    private String refreshToken;
}
