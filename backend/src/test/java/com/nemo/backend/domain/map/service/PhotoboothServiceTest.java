package com.nemo.backend.domain.map.service;

import com.nemo.backend.domain.map.dto.PhotoboothDto;
import com.nemo.backend.domain.map.util.NaverApiClient;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class PhotoboothServiceTest {

    @Test
    void mapSearchKeepsExistingResponseMapping() {
        NaverApiClient naverApiClient = mock(NaverApiClient.class);
        PhotoboothService service = new PhotoboothService(naverApiClient);
        when(naverApiClient.searchLocal("인생네컷", 5, 1, "random"))
                .thenReturn(Map.of("items", List.of(Map.of(
                        "title", "<b>인생네컷</b> 강남점",
                        "mapx", "1270000000",
                        "mapy", "375000000",
                        "roadAddress", "서울 강남구 테헤란로 1",
                        "link", "https://example.test/place/1"
                ))));

        List<PhotoboothDto> result = service.searchPhotobooths("인생네컷", null, null, 10);

        assertThat(result).singleElement().satisfies(item -> {
            assertThat(item.getName()).isEqualTo("인생네컷 강남점");
            assertThat(item.getBrand()).isEqualTo("인생네컷");
            assertThat(item.getLatitude()).isEqualTo(37.5);
            assertThat(item.getLongitude()).isEqualTo(127.0);
            assertThat(item.getRoadAddress()).isEqualTo("서울 강남구 테헤란로 1");
            assertThat(item.getNaverPlaceUrl()).isEqualTo("https://example.test/place/1");
        });
    }
}
