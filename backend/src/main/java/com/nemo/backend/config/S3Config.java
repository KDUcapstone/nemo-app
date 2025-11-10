package com.nemo.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.http.apache.ApacheHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;

import java.net.URI;
import java.time.Duration;

@Configuration
public class S3Config {

    @Value("${app.s3.region}")
    private String region;

    @Value("${app.s3.endpoint:}")   // LocalStack: http://localhost:4566 , 실AWS: 빈칸
    private String endpoint;

    @Value("${app.s3.accessKey}")
    private String accessKey;

    @Value("${app.s3.secretKey}")
    private String secretKey;

    @Value("${app.s3.pathStyle:true}")
    private boolean pathStyle;

    @Bean
    public S3Client s3Client() {
        var creds = StaticCredentialsProvider.create(
                AwsBasicCredentials.create(accessKey, secretKey));

        var s3Conf = S3Configuration.builder()
                .pathStyleAccessEnabled(pathStyle) // LocalStack = true, 실AWS = false 권장
                .build();

        var builder = S3Client.builder()
                .region(Region.of(region))
                .credentialsProvider(creds)
                .httpClientBuilder(ApacheHttpClient.builder())   // ★ 여기만 교체
                .serviceConfiguration(s3Conf);

        if (endpoint != null && !endpoint.isBlank()) {
            builder = builder.endpointOverride(URI.create(endpoint));
        }
        return builder.build();
    }
}
