import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/layout/LegalPage";

export const metadata: Metadata = {
  title: "이용약관",
  alternates: { canonical: "/terms/ko", languages: { en: "/terms" } },
};

export default function TermsKoPage() {
  return (
    <LegalPage
      title="이용약관"
      updated="2026년 8월 22일"
      updatedLabel="최종 수정"
      altHref="/terms"
      altLabel="English"
    >
      <LegalSection heading="1. 동의">
        Scoor 앱 또는 scoor.app 웹사이트를 이용하면 본 약관에 동의한 것으로
        봅니다. 동의하지 않는 경우 서비스를 이용할 수 없습니다.
      </LegalSection>

      <LegalSection heading="2. 서비스 내용">
        Scoor는 하루를 점수로 기록하는 개인 저널이자, 공개된 주제에 점수를 매기고
        의견을 남길 수 있는 서비스입니다. &ldquo;공식&rdquo; 배지가 붙은 글은
        Scoor가 작성한 글이며, 그 외의 글은 다른 이용자가 작성한 글입니다.
      </LegalSection>

      <LegalSection heading="3. 이용자의 콘텐츠">
        이용자가 작성한 콘텐츠의 권리는 이용자에게 있습니다. 공개 게시물을
        올리는 경우, 다른 이용자가 볼 수 있도록 서비스 내에서 이를 저장·표시할
        수 있는 제한적 권리를 Scoor에 부여하게 됩니다. 콘텐츠는 언제든 삭제할 수
        있습니다.
      </LegalSection>

      <LegalSection heading="4. 금지 행위">
        법령을 위반하거나, 타인을 괴롭히거나 비방하거나, 권리 없는 콘텐츠를
        게시하거나, 서비스를 방해하거나 역설계하는 행위를 할 수 없습니다.
        위반 콘텐츠는 앱 안에서 신고하거나 차단할 수 있으며, Scoor는 신고를
        검토해 콘텐츠를 숨기거나 계정 이용을 제한할 수 있습니다.
      </LegalSection>

      <LegalSection heading="5. 계정 삭제">
        설정에서 언제든 계정을 삭제할 수 있습니다. 삭제하면 계정과 콘텐츠가
        영구적으로 제거되며 복구할 수 없습니다.
      </LegalSection>

      <LegalSection heading="6. 면책 및 책임의 한계">
        Scoor는 &ldquo;있는 그대로&rdquo; 제공되며 어떠한 보증도 하지 않습니다.
        관련 법령이 허용하는 최대 범위에서, Scoor는 간접·부수적·결과적 손해 또는
        데이터 손실에 대해 책임을 지지 않습니다.
      </LegalSection>

      <LegalSection heading="7. 약관의 변경">
        서비스 발전에 따라 약관이 변경될 수 있습니다. 중요한 변경은 시행 전에 앱
        또는 이 페이지에 공지합니다.
      </LegalSection>

      <LegalSection heading="8. 문의">
        약관 관련 문의: legal@scoor.app.
      </LegalSection>
    </LegalPage>
  );
}
