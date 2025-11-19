// backend/src/main/java/com/nemo/backend/domain/album/dto/AlbumDetailResponse.java
package com.nemo.backend.domain.album.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.nemo.backend.domain.photo.dto.PhotoResponseDto;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AlbumDetailResponse {

    private Long albumId;
    private String title;
    private String description;
    private String coverPhotoUrl;
    private int photoCount;
    private LocalDateTime createdAt;

    /**
     * OWNER / CO_OWNER / EDITOR / VIEWER
     */
    private String role;

    /**
     * 명세에도 있는 photoIdList (그대로 유지)
     */
    private List<Long> photoIdList;

    /**
     * ⚠ 내부적으로는 PhotoResponseDto 리스트를 들고 있지만
     * 그대로 JSON으로 내보내지 않고, 아래의 getPhotoSummaryList()에서
     * 명세용 경량 DTO로 변환해서 노출한다.
     */
    @JsonIgnore
    private List<PhotoResponseDto> photoList;

    /**
     * 🔥 실제로 JSON에 찍히는 photoList
     * 명세:
     * [
     *   {
     *     "photoId": 101,
     *     "imageUrl": "...",
     *     "takenAt": "2025-07-20T14:00:00",
     *     "location": "홍대 포토그레이",
     *     "brand": "인생네컷"
     *   }
     * ]
     */
    @JsonProperty("photoList")
    public List<AlbumPhotoSummary> getPhotoSummaryList() {
        if (photoList == null || photoList.isEmpty()) {
            return Collections.emptyList();
        }
        return photoList.stream()
                .map(p -> new AlbumPhotoSummary(
                        p.getId(),                  // photoId
                        p.getImageUrl(),            // imageUrl
                        p.getTakenAt(),             // takenAt (LocalDateTime → ISO 문자열)
                        p.getLocationName(),        // location
                        p.getBrand()                // brand
                ))
                .collect(Collectors.toList());
    }

    /**
     * 📦 앨범 상세에서 사용하는 "요약 사진 정보" DTO
     * 명세에 맞춰서 필요한 필드만 가진다.
     */
    @Getter
    @AllArgsConstructor
    public static class AlbumPhotoSummary {
        private Long photoId;
        private String imageUrl;
        private LocalDateTime takenAt;
        private String location;
        private String brand;
    }
}
