# Вопросы производителю V8 и 2208A для проекта YUMN

Подготовлено 18 сентября 2026 года. Текст ниже можно отправить производителю. Письмо не отправлено.

Критичные ответы до интеграции: точная модель и прошивка, идентификация модели по BLE, расшифровка HRV/PPI и сна, глубина истории, продолжение синхронизации, условия работы в фоне, OTA и право коммерческого использования SDK. Просим отвечать отдельно для V8 и 2208A, с примерами пакетов и ссылками на конкретную версию документации. Наличие метода в общем SDK не считаем подтверждением функции конкретного устройства.

## Готовое письмо на английском

Subject: YUMN integration — device capabilities and protocol clarification for V8 and 2208A

Hello,

We are developing YUMN, a Flutter application for iOS and Android with our own backend. We received `V8 SDK-20260319.zip` and `2208A_SDK.zip`. We need to support the existing device and evaluate another wearable for deployment through sports schools and clubs, including use by minors.

Please answer the questions below for each exact device model and firmware version. Please distinguish hardware support, firmware support, SDK support and features available only in your reference app or cloud.

### A Device identification and SDK versions — required before integration

1. Which commercial model names, hardware revisions, chipsets and firmware versions correspond to each archive? Is 2208A a separate device family or a successor to the supplied V8 device? Please provide photos, labels and a compatibility matrix.
2. Which package is the supported production SDK for Android, iOS and Flutter? The 2208A archive contains components with 2024 dates as well as a Flutter package. Please provide release notes, version numbers and the authoritative protocol specification when packages disagree.
3. How can the app reliably identify the model and supported commands before writing settings? Please specify advertisement manufacturer data, service data, device information fields and capability commands, with packet examples. Both supplied SDKs use BCD time and expose an MTU field in the time acknowledgement; these fields do not distinguish the models.
4. What Android/iOS/Flutter versions, minimum OS versions, BLE MTU and notification sizes are supported? Which combinations have you tested on physical devices?
5. Can two models coexist in one app? Can a device connect to more than one phone, and how are ownership, pairing, unbinding and transfer to another user handled?

### B Sensors and meaning of measurements — required before analytics

6. For HR, HRV, SpO2, temperature, steps, accelerometer, gyroscope and respiration, please list: hardware presence, real-time availability, automatic sampling intervals, stored history, units, resolution and invalid/missing-value markers.
7. What precisely is the `HRV` field: RMSSD, SDNN or a proprietary score? What are its units, measurement window, filtering, minimum valid samples, posture requirements and timestamp meaning? Is it derived from ECG RR intervals or optical pulse intervals?
8. Can we obtain timestamped RR/PPI intervals and raw PPG/ECG samples? Specify units, sample rate, sequence numbers, quality flags, limits, real-time versus history access, and whether continuous nighttime collection is available. V8 exposes `GetPPI`; 2208A Flutter exposes PPG/PPI measurement switches. What is the equivalent history API on 2208A?
9. How are non-wear, motion artefacts, poor contact, charging and failed measurements represented? Does zero mean a measured value, unavailable data or device error for each field?
10. Is temperature skin temperature, estimated body temperature or another measurement? Which sensor location, calibration, units and accuracy apply? Are axillary-temperature commands relevant to the supplied wrist device? The supplied 2208A Android and Flutter realtime parsers differ in temperature scaling and optional SpO2 fields. Which layout is authoritative for each firmware?
11. What is the meaning and methodology of any vendor stress, fatigue, blood-pressure or respiration fields? Which are proprietary indices? Please provide validation evidence and limitations, including age ranges.

### C Sleep — required before showing duration or stages

12. For command `0x53`, define every value in `arraySleepQuality` / `ArraySleep`, including values such as 0, 4, 6, 29, 53, 200 and 255. Are these activity counts, stage codes, quality values or flags? Please provide the complete mapping rather than example numbers only.
13. Both inspected SDK parsers handle 34-byte records with 5-minute units and 130-byte records with 1-minute units. What selects each format? Can a notification contain multiple long records? Are records ever split across notifications?
14. Does the firmware provide Awake, Light, Deep and REM directly? V8 also exposes detailed sleep levels separately. Please specify that command, code mapping and supported firmware. Does 2208A have an equivalent?
15. How are naps, multiple episodes, midnight, timezone changes, awake gaps and non-wear handled? Are sleep results revised after synchronization, and how should the app identify revised records?
16. If stages or Sleep Score are calculated only by your reference app/cloud, can we license the algorithm or receive a supported library/API? Please provide the reference app version, sample export and expected output for the same recorded night.

### D History, synchronization and time — required before reliable collection

17. How many hours/days of each metric are retained, at each sampling setting? What happens when memory fills, the battery drains or a firmware update occurs? Is history read destructive?
18. Please document start, next-page, resume, completion, error and delete modes for every history command, including the exact meaning of `0x00`, `0x02` and `0x99`. What page limit requires a continuation request?
19. Please provide packet examples for empty history, a full page, a final page with data and `0x53 0xFF`, record IDs containing `0xFF`, interrupted transfers, retransmissions and error replies. Specify CRC/checksum rules for commands and notifications separately.
20. Which stable record ID or sequence number should be used for deduplication? How can the app resume after a Bluetooth disconnect without losing records or duplicating them?
21. Are timestamps device-local time or UTC? How are timezone offsets, half-hour zones, daylight saving changes and clock correction represented? Does setting time alter historical records?
22. Can measurement, history synchronization and workout mode run together? Specify command ordering, acknowledgements, minimum delays, timeouts and whether commands may be in flight concurrently.

### E Workouts, battery and background operation

23. Please confirm the `0x18` layout for each firmware. The supplied V8 parser reads elapsed time at bytes 10–13; the 2208A Flutter parser does not expose it. What is the time unit? Is workout distance actually present anywhere in this packet?
24. Define `0x17` heartbeat fields and required cadence. Is `space` pace in seconds per kilometre? What should the phone send when GPS distance/pace is unavailable? Is heartbeat required for V8, 2208A or only selected modes, including while paused?
25. What happens to a workout if the app is suspended, terminated, Bluetooth disconnects or the phone reboots? Can the workout be recovered from device history? How are phone-initiated stop and device-initiated stop distinguished?
26. Provide battery life measurements for the proposed HR/HRV/SpO2/temperature settings, raw PPG/PPI streaming and workout mode. Include charging time, water-resistance conditions, storage limits and wear-detection behaviour.
27. Which iOS background restoration and Android foreground-service approaches do you officially support? Please supply tested sample apps and known OS/manufacturer limitations.

### F Firmware updates, licensing and support

28. Please provide the complete OTA procedure for each model: supported DFU protocol, model/version checks, signed firmware verification, minimum battery, interruption recovery, rollback and recovery from failed updates. Who supplies and authorizes production firmware?
29. May we commercially distribute the SDK in our own branded app and use our own backend? Are there per-device/user fees, redistribution restrictions, activation keys, mandatory accounts/cloud services, expiry dates or telemetry sent to your servers?
30. Please provide privacy/data-flow documentation, third-party SDK licenses and software component inventory. Can every measurement and update workflow function without your cloud?
31. Provide validation reports for the exact hardware/firmware and intended age range, regional conformity documents, warranty terms, expected support period and SDK/firmware change notification policy. Please distinguish wellness capabilities from certified medical claims.
32. Please supply one test device of each supported hardware revision, current firmware, reference apps, a 24-hour anonymized recording with expected decoded output, and a technical contact for protocol questions.

Please return a table with: question number, model, firmware, supported/not supported, limitations, command/API, evidence/example and expected delivery date for missing information. For undocumented or unavailable features, please state that explicitly.

Thank you.

## Проверка после получения ответов

Сопоставить каждую заявленную функцию с образцом устройства. Проверить сутки истории без телефона, повторную синхронизацию, обрыв на середине страницы, завершение потока, смену времени, сон за несколько суток, тренировку с паузой и уходом приложения в фон. Сохранить обезличенные BLE-пакеты и ожидаемый результат как регрессионные фикстуры. OTA проверять только подходящим для модели официальным образом прошивки.
