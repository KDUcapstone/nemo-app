// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumOwnershipFilter.java
package com.nemo.backend.domain.album.dto;

public enum AlbumOwnershipFilter {
    ALL, OWNED, SHARED;

    public static AlbumOwnershipFilter from(String raw) {
        if (raw == null || raw.isBlank()) return ALL;
        try {
            return AlbumOwnershipFilter.valueOf(raw.toUpperCase());
        } catch (IllegalArgumentException e) {
            return ALL;
        }
    }
}
