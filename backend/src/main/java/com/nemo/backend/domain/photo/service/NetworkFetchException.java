package com.nemo.backend.domain.photo.service;

import com.nemo.backend.global.exception.ApiException;
import com.nemo.backend.global.exception.ErrorCode;

public class NetworkFetchException extends ApiException {
  public NetworkFetchException(String message, Throwable cause) { super(ErrorCode.NETWORK_FAILED, message, cause); }
}
