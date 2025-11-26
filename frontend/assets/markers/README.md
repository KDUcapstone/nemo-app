# 포토부스 마커 이미지 가이드

이 폴더에 브랜드별 마커 이미지를 추가해주세요.

## 필요한 이미지 파일

다음 이름으로 이미지 파일을 저장해주세요:

1. **lifefourcuts.png** - 인생네컷 마커 (Life Four Cuts)
2. **photogray.png** - 포토그레이 마커
3. **harufilm.png** - 하루필름 마커
4. **photoism.png** - 포토이즘 마커 (Photoism)

## 이미지 사양

- **권장 크기**: 80x80px ~ 120x120px
- **형식**: PNG (투명 배경 권장)
- **파일 크기**: 50KB 이하 권장

## 파일 구조

```
frontend/
  └── assets/
      └── markers/
          ├── photoism.png          # 인생네컷
          ├── photogray.png         # 포토그레이
          ├── harufilm.png          # 하루필름
          ├── photoism_brand.png    # 포토이즘
          └── README.md             # 이 파일
```

## 이미지 추가 후

이미지 파일을 추가한 후 다음 명령어를 실행하세요:

```bash
cd frontend
flutter pub get
flutter clean
flutter run
```

## 주의사항

- 이미지 파일명은 정확히 위의 이름과 일치해야 합니다 (대소문자 구분)
- PNG 형식을 사용하세요
- 투명 배경을 사용하면 지도에서 더 깔끔하게 표시됩니다

