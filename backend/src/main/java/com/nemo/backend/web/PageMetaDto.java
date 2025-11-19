package com.nemo.backend.web;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** 프론트 명세용 page 블록 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PageMetaDto {
    private int size;
    private long totalElements;
    private int totalPages;
    private int number;
}
