package com.test.SpringbootApp;

import com.nemo.backend.BackendApplication;
import com.nemo.backend.domain.map.util.NaverApiClient;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import software.amazon.awssdk.services.s3.S3Client;

@SpringBootTest(classes = BackendApplication.class)
@ActiveProfiles("dev")
class SpringbootAppApplicationTests {
	@MockitoBean
	private S3Client s3Client;
	@MockitoBean
	private NaverApiClient naverApiClient;

	@Test
	void contextLoads() {
	}

}
