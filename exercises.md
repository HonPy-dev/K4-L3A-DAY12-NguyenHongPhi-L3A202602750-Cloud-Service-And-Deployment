# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Hồng Phi  Mã học viên: L3A202602750

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Giả sử deploy lên Railway mà quên set `AGENT_API_KEY` trong dashboard. Nếu
`agent_api_key` có mặc định `"changeme"` thì app vẫn khởi động bình thường,
endpoint `/ask` live công khai và ai biết lab này cũng biết khóa mặc định —
họ gọi API bằng khóa đó, tiêu ngân sách `MONTHLY_BUDGET_USD` của mình mà
mình không hề hay biết, vì log vẫn ghi user "anonymous" trông bình thường.
Với khóa không có mặc định, app crash đúng lúc khởi động, Railway hiện ngay
deploy fail trong dashboard, mình phát hiện trong vài giây thay vì sau khi
hóa đơn/token đã bị đốt. Chết sớm ở đây rẻ hơn rất nhiều so với sống mòn
mang lỗ hổng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thật thu được khi chạy service ở máy và gọi `/ask`:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T08:16:26.904557+00:00", "user_id": "sv01", "tokens_in": 48, "tokens_out": 46, "cost_usd": 3.48e-05}
```

Hai việc làm được với dòng này mà `print("đã trả lời xong")` không làm được:

1. **Lọc và đếm theo trường**: `grep '"event": "ask_completed"' | wc -l` đếm
   chính xác số request hoàn tất, hoặc lọc theo `user_id` để xem user nào
   đang gọi nhiều — chuỗi "đã trả lời xong" không tách được user hay chi phí
   ra vì không có cấu trúc.
2. **Cảnh báo/giám sát tự động**: vì mỗi dòng là một JSON hợp lệ với
   `cost_usd`, `tokens_in/out`, `timestamp`, mình có thể viết query trên
   dashboard (Railway log filter, Datadog) kiểu "tổng cost_usd theo giờ"
   hoặc cảnh báo khi `level` xuất hiện `error`. Log text tự do không parse
   được bằng máy nên không thể tự động hóa các việc này.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 310 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Chênh lệch ~1.4GB chủ yếu là: (1) base image — bản 1 stage dùng `python:3.11`
đầy đủ chứa compiler GCC, headers, các tool GNU, tài liệu... trong khi bản
multi-stage dùng `python:3.11-slim`; (2) pip để lại build tool và cache khi
cài các package — stage builder cài xong thì chỉ có venv hoàn chỉnh được copy
sang stage runtime, toàn bộ trình cài đặt trung gian bị bỏ lại. Runtime image
chỉ còn Python runtime + venv + code, đúng nghĩa "mang theo thứ cần dùng,
không mang theo đồ nghề đã dựng xong".

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Kết quả build thật sau khi thêm 1 dòng comment vào `app/main.py`: các layer
`FROM`, `COPY requirements.txt` và `RUN pip install` đều báo `CACHED`, chỉ
layer `COPY . .` trở đi được chạy lại — tổng thời gian build chỉ vài giây.
Vì Docker cache theo thứ tự layer: layer chỉ invalidates khi layer trước nó
thay đổi hoặc chính lệnh của nó thay đổi. `requirements.txt` không đổi nên
layer pip install dùng lại được. Nếu đặt `COPY . .` trước `RUN pip install`
thì mọi lần sửa code đều làm layer `COPY . .` đổi, kéo theo layer phía sau —
bao gồm cả `pip install` — phải chạy lại toàn bộ, mỗi lần sửa 1 dòng là cài
lại sạch bộ thư viện, mất vài phút thay vì vài giây.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện: ứng dụng có lỗ hổng cho phép RCE (ví dụ endpoint nhận path
file, hoặc dependency cũ có CVE) → kẻ tấn công chạy được lệnh bên trong
container với quyền của process → process đang là root nên trong container
có toàn quyền ghi mọi file của app, cài công cụ, và nếu có thêm lỗi cấu
hình (container mount volume nhạy cảm, chạy `--privileged`, hoặc exploit
lỗ hổng container escape) thì quyền root trong container đủ điều kiện leo
lên quyền root trên host. Lệnh `USER appuser` cắt đứt ngay mắt xích đầu:
process chỉ là user thường, ngay cả khi bị RCE thì kẻ tấn công cũng không
ghi được vào system file, không cài được package, và khi thoát ra host cũng
chỉ mang quyền của một user vô danh — khoảng cách tấn công dài hơn và dễ bị
phát hiện hơn nhiều.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt
được con số đó.

Tối đa 20 request trong 2 giây: gửi 10 request vào lúc 10:00:59 (đầy hạn mức
của cửa sổ phút 10:00) và 10 request nữa vào lúc 10:01:01 — đồng hồ vừa reset
nên counter sạch, chấp nhận thêm 10. Hai giây mà tiêu hết quota của hai phút.
Sliding window không có "mốc reset" nên tránh được: mỗi request mới, ZSET bỏ
hết các entry cũ hơn 60 giây rồi mới đếm — 10 request ở 10:00:59 vẫn còn nằm
trong cửa sổ khi tới 10:01:01 nên request thứ 11+ trong 2 giây đó bị 429.
Trong test của em, gọi 12 lần liên tiếp qua HTTP cho kết quả đúng 10 lần `200`
rồi 2 lần `429`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Rate limit giới hạn **tần suất** (số request mỗi phút), cost guard giới hạn
**tổng tiền** (USD mỗi tháng) — hai trục độc lập.

- Rate limit cho qua nhưng cost guard chặn: user lặp đều 5 request/phút (dưới
  hạn mức 10/phút, không bao giờ dính 429) suốt cả tháng, mỗi request câu
  hỏi dài kèm history 20 lượt nên ~50k token. Tần suất thấp nhưng tích lũy
  chi phí vượt `MONTHLY_BUDGET_USD` → 402.
- Cost guard cho qua nhưng rate limit chặn: user mới chưa tiêu xu nào, nhưng
  bấm spam 20 request liên tiếp trong vài giây, mỗi câu ngắn tốn vài token
  (tổng tiền không đáng kể) → request thứ 11 trở đi bị 429, cost guard vẫn
  thong thả vì ngân sách còn nguyên.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Theo đúng thứ tự: (1) Redis mất kết nối; (2) endpoint gộp (đang đóng vai
liveness) gọi `store.ping()` fail và trả 503; (3) orchestrator thấy liveness
probe fail → kết luận process chết → restart cả 3 container agent; (4) hàng
loạt request đang xử lý giữa chừng bị cắt, user thấy 502; (5) Redis hồi phục
sau 30 giây nhưng cụm container vừa bị restart lung tung, có thể còn đang
khởi động lại nên vẫn từ chối traffic; (6) kết cục: một sự cố phụ thuộc
(Redis nhấp nháy 30 giây) bị thổi thành sự cố toàn cụm. Tách riêng thì
/health không đụng Redis nên trả 200 suốt (process vẫn khỏe, chỉ là phụ thuộc
chưa sẵn sàng), còn /ready trả 503 để load balancer tạm dồn traffic — Redis
hồi phục là mọi thứ tự ổn, không restart gì cả.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Chạy thật 3 instance agent sau nginx (round-robin), gọi `/ask` 5 lần liên tiếp
cùng `X-User-Id: sv-scale`, kết quả: `history_length = 0, 2, 4, 6, 8` — tăng
đềnh đúng 2 mỗi lượt dù request rơi vào container khác nhau, vì cả 3 container
cùng đọc/ghi vào một Redis. Nếu lịch sử nằm trong dict Python của từng process
thì mỗi container có RAM riêng: request vào container B sẽ thấy history của
container B (rỗng hoặc thiếu), nên `history_length` nhảy loạn 0, 0, 2, 0, 2...
— agent "mất trí nhớ" mỗi khi câu hỏi rơi vào instance khác, đúng lý do state
phải đẩy ra ngoài process.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Trong lúc deploy lên Railway, lần đầu build xong nhưng healthcheck `/health`
timeout liên tục và deploy bị đánh fail, log container ghi
`uvicorn: error [Errno 98] address already in use` / process exit ngay lúc
khởi động. Xem log thấy lỗi cast biến: Railway gán `PORT` nhưng lần đầu mình
vẫn cố định `--port 8000` trong start command, trong khi platform proxy vào
cổng theo `$PORT` — hai bên nhìn hai cổng khác nhau nên probe không bao giờ
chạm được app. Sửa bằng cách để CMD đọc đúng `${PORT:-8000}` (và
`railway.toml` dùng `--port $PORT`), redeploy thì healthcheck pass, deploy
xanh. Bài học: cloud tự gán cổng, app phải đọc cấu hình từ môi trường thay vì
giả định cổng cố định — chính là nguyên tắc 12-factor ở CP1.
