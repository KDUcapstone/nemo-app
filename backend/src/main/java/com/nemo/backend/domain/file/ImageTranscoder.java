package com.nemo.backend.domain.file;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageTypeSpecifier;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import java.awt.color.ColorSpace;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.Iterator;

public final class ImageTranscoder {

    private ImageTranscoder() {}

    /**
     * JPEG 바이트가 CMYK 등 Android가 못 읽는 색공간이면 sRGB로 변환해 재인코딩.
     * 이미 sRGB/YCbCr이면 원본 그대로 반환.
     */
    public static byte[] normalizeJpegToSRGB(byte[] jpegBytes) {
        try {
            // TwelveMonkeys가 등록되어 있으면 CMYK JPEG도 읽힌다
            var in = ImageIO.createImageInputStream(new ByteArrayInputStream(jpegBytes));
            var readers = ImageIO.getImageReaders(in);
            if (!readers.hasNext()) return jpegBytes;

            var reader = readers.next();
            reader.setInput(in, true, true);

            // 메타정보 확인
            BufferedImage src = reader.read(0);
            var cs = src.getColorModel().getColorSpace();
            boolean notSRGB = cs == null || cs.getType() != ColorSpace.TYPE_RGB;

            // 대부분의 CMYK JPEG는 TYPE_CMYK로 들어옴 → TYPE_INT_RGB로 변환
            if (notSRGB || src.getType() != BufferedImage.TYPE_INT_RGB) {
                BufferedImage rgb = new BufferedImage(
                        src.getWidth(), src.getHeight(), BufferedImage.TYPE_INT_RGB);
                rgb.getGraphics().drawImage(src, 0, 0, null);
                src = rgb;
            }

            // JPEG로 재인코딩 (sRGB)
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            Iterator<ImageWriter> it = ImageIO.getImageWritersByFormatName("jpeg");
            if (!it.hasNext()) return jpegBytes;
            ImageWriter writer = it.next();
            try (var ios = new MemoryCacheImageOutputStream(bos)) {
                writer.setOutput(ios);
                ImageWriteParam param = writer.getDefaultWriteParam();
                param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
                param.setCompressionQuality(0.92f); // 품질
                writer.write(null, new IIOImage(src, null, null), param);
            } finally {
                writer.dispose();
            }
            return bos.toByteArray();
        } catch (Exception ignore) {
            // 실패 시 원본 그대로 (손상 방지)
            return jpegBytes;
        }
    }

    /** 간단 확장자 체크 */
    public static boolean looksLikeJpeg(String keyOrCt) {
        String s = keyOrCt == null ? "" : keyOrCt.toLowerCase();
        return s.endsWith(".jpg") || s.endsWith(".jpeg") || s.contains("image/jpeg");
    }
}
