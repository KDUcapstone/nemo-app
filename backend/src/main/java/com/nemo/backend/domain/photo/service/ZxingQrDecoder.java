package com.nemo.backend.domain.photo.service;

import com.google.zxing.*;
import com.google.zxing.client.j2se.BufferedImageLuminanceSource;
import com.google.zxing.common.HybridBinarizer;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.InputStream;
import java.util.Collections;
import java.util.EnumMap;
import java.util.Map;

@Primary
@Component
public class ZxingQrDecoder implements QrDecoder {
    @Override
    public String decode(MultipartFile qrFile) {
        try (InputStream is = qrFile.getInputStream()) {
            BufferedImage image = ImageIO.read(is);
            if (image == null) return null;

            // ZXing 힌트 설정 (TRY_HARDER: 검출 강도 높임, POSSIBLE_FORMATS: QR코드만 탐색)
            Map<DecodeHintType, Object> hints = new EnumMap<>(DecodeHintType.class);
            hints.put(DecodeHintType.TRY_HARDER, Boolean.TRUE);
            hints.put(DecodeHintType.POSSIBLE_FORMATS, Collections.singletonList(BarcodeFormat.QR_CODE));

            // 0°, 90°, 180°, 270° 회전까지 시도
            for (int i = 0; i < 4; i++) {
                BufferedImage rotated = (i == 0) ? image : rotate90(image, i);
                LuminanceSource source = new BufferedImageLuminanceSource(rotated);
                BinaryBitmap bitmap = new BinaryBitmap(new HybridBinarizer(source));
                try {
                    Result result = new MultiFormatReader().decode(bitmap, hints);
                    return result.getText();
                } catch (NotFoundException e) {
                    // 계속 회전 후 재시도
                }
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    /** 이미지를 90도 단위로 회전시키는 헬퍼 메서드 */
    private BufferedImage rotate90(BufferedImage img, int times) {
        int angle = (times * 90) % 360;
        int w = img.getWidth();
        int h = img.getHeight();
        BufferedImage result;
        if (angle == 90 || angle == 270) {
            result = new BufferedImage(h, w, img.getType());
        } else {
            result = new BufferedImage(w, h, img.getType());
        }
        Graphics2D g2 = result.createGraphics();
        g2.rotate(Math.toRadians(angle), w / 2.0, h / 2.0);
        // 중심 축 변경에 따라 offset 조정
        if (angle == 90) {
            g2.translate(0, - (h - w) / 2.0);
        } else if (angle == 270) {
            g2.translate(- (w - h) / 2.0, 0);
        }
        g2.drawImage(img, 0, 0, null);
        g2.dispose();
        return result;
    }
}
