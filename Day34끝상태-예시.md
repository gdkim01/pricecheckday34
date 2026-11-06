# Day34 끝 상태 (교육용 가상 예시)

내 값이 아니고, 실제 키·실제 주소가 아닙니다. 칸이 어떤 모양으로 채워지는지만 봅니다. 값이 `…`인 칸은 내 컴퓨터에서 직접 확인해 적는 칸입니다.

[시작]
- 과제 9(했음·안 함): 안 함
- 오늘 쓴 화면과 폴더 위치(ZIP의 price-check.html 또는 내 화면): ZIP의 price-check.html. 폴더는 내 문서 안 day34-작업

[오늘 판단]
- 이 기능에서 AI가 쓰는 것: 가격 설명 문장
- 프로그램이 정하는 것: 가격(기준 자료), 모델 이름, 글자 수, 호출 횟수
- 내가 확인하는 것: 설명이 기준 자료에 없는 말을 하지 않았는지, 로그인한 사람만 저장·승인되는지

[시험 결과]
| 시험 | 입력 | 기대 | 내가 본 것 | 판정 |
|---|---|---|---|---|
| 정상 | B-200, 이 가격은 왜 79,000원이에요? | 79,000원 + AI 설명 | 79,000원이 먼저 나오고 설명 두 문장이 붙음 | 통과 |
| 빈 질문 | 질문 칸 비움 | 79,000원 + 질문 안내 | … | … |
| AI 실패 | AI_MOCK_FAIL=unavailable | 79,000원 + 바쁨 안내 | 79,000원은 그대로, "AI가 지금 바빠 설명을 만들지 못했습니다" 안내가 나옴 | 통과 |
| 저장·승인 | 로그인 → 대기로 저장 → 승인 | 확인자·시각이 남음 | … | … |

[Day35 입력]
- 실제 화면 경로(작업 폴더 기준): price-check.html
- 실행 명령(실행한 폴더): vercel dev (작업 폴더 맨 위)
- 화면을 연 주소: 터미널에 나온 localhost 주소 + /price-check.html
- API 경로: /api/explain
- 설정 이름(값은 적지 않음): ANTHROPIC_API_KEY, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, AI_MOCK_FAIL(비움)
- config.js에 든 설정 이름(값은 적지 않음): SUPABASE_URL, SUPABASE_KEY
- 배포할 파일 목록(후보): price-check.html, check-explanation.js, api/explain.js, package.json, package-lock.json
- 올리지 않을 파일: .env, .vercel/, node_modules/, 오늘 쓴 ZIP, Day34끝상태.md

[기타]
- 이전 .env 처리(과제 9를 한 경우만): 해당 없음
- 실행하지 못한 것: …
