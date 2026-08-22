import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/layout/LegalPage";

export const metadata: Metadata = {
  title: "개인정보처리방침",
  alternates: { canonical: "/privacy/ko", languages: { en: "/privacy" } },
};

export default function PrivacyKoPage() {
  return (
    <LegalPage
      title="개인정보처리방침"
      updated="2026년 8월 22일"
      updatedLabel="최종 수정"
      altHref="/privacy"
      altLabel="English"
    >
      <LegalSection heading="개요">
        Scoor는 하루를 0~100점으로 기록하고, 사람들이 같은 주제를 어떻게 느끼는지
        보여주는 앱입니다. 이 방침은 Scoor iOS 앱과 scoor.app 웹사이트가 어떤
        정보를 다루고 그 정보가 어디에 저장되는지를 설명합니다.
      </LegalSection>

      <LegalSection heading="기기에 저장되는 정보">
        Scoor는 로컬 우선(local-first) 방식입니다. 점수, 사유, 방명록, 프로필,
        테마·알림 설정은 먼저 기기에 저장되며 네트워크가 없어도 앱은 그대로
        동작합니다. 로그인 토큰은 iOS 키체인에 보관됩니다.
      </LegalSection>

      <LegalSection heading="서버로 전송되는 정보">
        로그인한 상태에서는 일별 점수(점수, 선택 사유, 날짜)와 프로필(닉네임,
        아바타 이모지, 소개)이 기기 간 동기화를 위해 백업됩니다. World 토픽
        점수와 코멘트, 피드 댓글, 좋아요처럼 다른 사람에게 공개되는 활동은
        성격상 서버에 저장됩니다. 신고와 차단 기록도 처리 목적으로 저장됩니다.
        서버는 Supabase(관리형 PostgreSQL) 서울 리전에서 운영됩니다.
      </LegalSection>

      <LegalSection heading="수집 항목과 이용 목적">
        회원 식별을 위한 계정 식별자와 이메일 주소, 서비스 제공을 위한 위 기록이
        전부입니다. 광고나 프로파일링 목적의 수집은 하지 않습니다.
      </LegalSection>

      <LegalSection heading="보유 및 파기">
        회원 정보와 기록은 회원 탈퇴 시 즉시 파기됩니다. 별도의 보관 기간을 두지
        않으며, 법령상 보존 의무가 있는 경우에만 해당 기간 동안 보관합니다.
      </LegalSection>

      <LegalSection heading="로그인">
        인증은 Apple, Google 또는 이메일로 이루어집니다. Scoor는 계정 식별자와,
        이용자가 제공에 동의한 경우 이메일 주소를 받습니다. 이메일 비밀번호는
        어떤 경우에도 평문으로 저장하지 않습니다.
      </LegalSection>

      <LegalSection heading="위치정보">
        Scoor는 GPS를 사용하지 않으며 위치 권한을 요청하지 않습니다. 글 옆에
        표시되는 국가는 이용자가 직접 설정한 값입니다.
      </LegalSection>

      <LegalSection heading="계정 삭제">
        앱의 설정 → 계정 → 계정 및 데이터 삭제에서 계정을 삭제할 수 있습니다.
        이는 실제 서버 측 삭제입니다 — 프로필, 점수, 글, 댓글, 좋아요, 신고,
        차단 기록이 함께 삭제되고 Apple 로그인 토큰은 Apple에 폐기 요청됩니다.
        기기에 저장된 사본도 같은 시점에 지워집니다. 삭제는 되돌릴 수 없습니다.
      </LegalSection>

      <LegalSection heading="알림">
        일일 리마인더는 iOS 로컬 알림으로 예약되며, 앱 또는 iOS 설정에서 언제든
        끌 수 있습니다.
      </LegalSection>

      <LegalSection heading="분석 및 추적">
        앱에는 제3자 분석 도구, 광고 SDK, 앱 간 추적 기능이 포함되어 있지 않으며
        앱 추적 투명성(ATT) 권한도 요청하지 않습니다.
      </LegalSection>

      <LegalSection heading="이용자의 권리">
        이용자는 언제든 자신의 정보에 대한 열람·정정·삭제·처리정지를 요청할 수
        있습니다. 앱 내 계정 삭제로 즉시 처리하거나, 아래 연락처로 요청해 주세요.
      </LegalSection>

      <LegalSection heading="변경 및 문의">
        중요한 변경은 시행 전에 이 페이지에 공지합니다. 개인정보 관련 문의:
        privacy@scoor.app.
      </LegalSection>
    </LegalPage>
  );
}
