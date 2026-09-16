import {
  LayoutGrid,
  ListTodo,
  Rss,
  Users,
  ChartNoAxesCombined,
  Bell,
  Globe,
  Settings,
} from "lucide-react";
export const navigation = [
  {
    label: "운영 개요",
    href: "/admin",
    icon: LayoutGrid,
    group: "워크스페이스",
  },
  {
    label: "월드 토픽",
    href: "/admin/topics",
    icon: ListTodo,
    group: "콘텐츠",
  },
  { label: "피드", href: "/admin/feed", icon: Rss, group: "콘텐츠" },
  {
    label: "사용자",
    href: "/admin/users",
    icon: Users,
    group: "미리보기",
    preview: true,
  },
  {
    label: "분석",
    href: "/admin/analytics",
    icon: ChartNoAxesCombined,
    group: "미리보기",
    preview: true,
  },
  {
    label: "알림",
    href: "/admin/notifications",
    icon: Bell,
    group: "미리보기",
    preview: true,
  },
  {
    label: "월드 아젠다",
    href: "/admin/agenda",
    icon: Globe,
    group: "미리보기",
    preview: true,
  },
  {
    label: "설정",
    href: "/admin/settings",
    icon: Settings,
    group: "워크스페이스",
  },
];
