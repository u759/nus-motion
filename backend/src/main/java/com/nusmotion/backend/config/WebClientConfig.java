package com.nusmotion.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpRequestInterceptor;
import org.springframework.http.client.ClientHttpResponse;
import org.springframework.web.client.RestClient;

import java.io.IOException;
import java.io.InputStream;

/**
 * Creates a pre-configured RestClient bean pointing at the NUS NextBus API.
 *
 * LEARNING NOTE:
 * - RestClient (Spring Boot 3.2+) is the modern synchronous HTTP client.
 * - The upstream NUS API returns Content-Type "text/html" even though the body is JSON.
 *   We add an interceptor that rewrites the response Content-Type to application/json
 *   so Jackson's converter can deserialize it.
 */
@Configuration
public class WebClientConfig {

    @Bean
    public RestClient nusApiClient(NusApiProperties props) {
        return RestClient.builder()
                .baseUrl(props.baseUrl())
                .defaultHeader(HttpHeaders.AUTHORIZATION, props.authHeader())
                .defaultHeader(HttpHeaders.USER_AGENT, props.userAgent())
                .requestInterceptor(contentTypeFixer())
                .build();
    }

    private ClientHttpRequestInterceptor contentTypeFixer() {
        return (request, body, execution) -> {
            ClientHttpResponse original = execution.execute(request, body);
            MediaType contentType = original.getHeaders().getContentType();
            if (contentType != null && contentType.isCompatibleWith(MediaType.TEXT_HTML)) {
                return new ContentTypeOverrideResponse(original, MediaType.APPLICATION_JSON);
            }
            return original;
        };
    }

    private static class ContentTypeOverrideResponse implements ClientHttpResponse {
        private final ClientHttpResponse delegate;
        private final HttpHeaders headers;

        ContentTypeOverrideResponse(ClientHttpResponse delegate, MediaType overriddenType) {
            this.delegate = delegate;
            this.headers = new HttpHeaders();
            this.headers.putAll(delegate.getHeaders());
            this.headers.setContentType(overriddenType);
        }

        @Override public HttpStatusCode getStatusCode() throws IOException { return delegate.getStatusCode(); }
        @Override public String getStatusText() throws IOException { return delegate.getStatusText(); }
        @Override public HttpHeaders getHeaders() { return headers; }
        @Override public InputStream getBody() throws IOException { return delegate.getBody(); }
        @Override public void close() { delegate.close(); }
    }
}
