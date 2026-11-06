function checkExplanation(d) {
  const fail=(problem,received,expected,fix)=>({status:'확인 필요',reason:problem+' / 받은 값: '+String(received)+' / 기대값: '+expected+' / 어떻게 고치나: '+fix});
  const prices={'B-200':79000,'A-100':98000};
  if(!Object.hasOwn(prices,d.code)) return fail('상품 코드 형식',d.code,'B-200 또는 A-100','가격자료 코드를 확인하세요.');
  if(!Number.isInteger(d.price)||d.price!==prices[d.code]) return fail('확정 가격 칸 오류',d.price,prices[d.code],'가격자료의 확정 가격을 숫자로 입력하세요.');
  if(typeof d.explain!=='string'||!d.explain.trim()) return fail('빈 설명',d.explain,'설명 문장','설명을 새로 작성해 검사하세요.');
  const found=[...d.explain.matchAll(/확정 가격은\s*([^\s원]+)원/g)];
  if(found.length!==1) return fail('가격 구절 형식',d.explain,'확정 가격은 숫자원 구절 1개','가격 구절을 확인해 새 설명으로 검사하세요.');
  const raw=found[0][1];
  if(!/^(?:0|[1-9]\d*|[1-9]\d{0,2}(?:,\d{3})+)$/.test(raw)) return fail('금액 형식 오류',raw,'79000 또는 79,000 같은 정수','쉼표 위치와 숫자 형식을 확인하세요.');
  const amount=Number(raw.replaceAll(',',''));
  if(amount!==d.price) return fail('확정 가격 불일치',amount,d.price,'원문과 대조해 설명을 새로 작성하고 새 대기 행으로 재검사하세요.');
  return {status:'검사 통과 · 내용 미승인',reason:'금액 형식과 확정 가격 일치. 상품 연결·배송 조건은 사람이 원문과 대조하세요.'};
}
