// com.nemo.backend.domain.photo.service.PhotoStorage
package com.nemo.backend.domain.photo.service;

import org.springframework.web.multipart.MultipartFile;

public interface PhotoStorage {
    /** 순수 multipart 파일을 저장하고 키(경로)를 반환 */
    String store(MultipartFile file) throws Exception;

    /** URL 크롤링 등으로 확보한 바이트를 직접 저장하고 키(경로)를 반환 */
    String storeBytes(byte[] data, String originalFilename, String contentType) throws Exception;
}
