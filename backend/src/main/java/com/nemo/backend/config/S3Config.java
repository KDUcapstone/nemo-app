package com.nemo.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.http.apache.ApacheHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

import java.net.URI;
import java.time.Duration;

@Configuration
public class S3Config {

    @Value("${app.s3.region}")
    private String region;                // LocalStack/실AWS 공통 (예: ap-northeast-2)

    @Value("${app.s3.endpoint:}")         // LocalStack: http://localhost:4566 , 실AWS: 빈칸
    private String endpoint;

    @Value("${app.s3.accessKey}")
    private String accessKey;

    @Value("${app.s3.secretKey}")
    private String secretKey;

    @Value("${app.s3.pathStyle:true}")    // LocalStack=true, 실AWS=false 권장
    private boolean pathStyle;

    @Bean
    public S3Client s3Client() {
        var creds = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKey, secretKey));

        var s3Conf = S3Configuration.builder()
                .pathStyleAccessEnabled(pathStyle)
                .build();

        var http = ApacheHttpClient.builder()
                .connectionTimeout(Duration.ofSeconds(5))
                .socketTimeout(Duration.ofSeconds(30))
                .maxConnections(64)
                .build();

        var override = ClientOverrideConfiguration.builder()
                .apiCallTimeout(Duration.ofSeconds(60))
                .apiCallAttemptTimeout(Duration.ofSeconds(30))
                .build();

        var builder = S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(creds)
                .httpClient(http)
                .overrideConfiguration(override)
                .serviceConfiguration(s3Conf);

        if (endpoint != null && !endpoint.isBlank()) {
            builder = builder.endpointOverride(URI.create(endpoint));
        }
        return builder.build();
    }
}
