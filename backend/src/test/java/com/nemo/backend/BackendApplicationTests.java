package com.nemo.backend;

import com.nemo.backend.domain.map.util.NaverApiClient;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import software.amazon.awssdk.services.s3.S3Client;

@SpringBootTest
@ActiveProfiles("dev")
class BackendApplicationTests {
	@MockitoBean
	private S3Client s3Client;
	@MockitoBean
	private NaverApiClient naverApiClient;

	@Test
	void contextLoads() {
	}

}
