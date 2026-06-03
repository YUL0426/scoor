//
//  MyPageView.swift
//  Scoor
//
//  Tab 4: Profile, calendar score visualization, guestbook.
//

import SwiftUI

struct MyPageView: View {
    @EnvironmentObject private var appServices: AppServices
    @StateObject private var viewModel: MyPageViewModel
    @State private var showSettings = false
    @State private var showProfileEdit = false
    @State private var calendarRoute: CalendarRoute?

    init(scoreService: ScoreServiceProtocol, userService: UserServiceProtocol, guestbookService: GuestbookServiceProtocol) {
        _viewModel = StateObject(wrappedValue: MyPageViewModel(
            scoreService: scoreService,
            userService: userService,
            guestbookService: guestbookService
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.currentUser != nil {
                    ProfileHeaderView(
                        username: viewModel.currentUser!.username,
                        bio: viewModel.currentUser!.bio,
                        monthlyAverage: viewModel.monthlyAverage,
                        onEditProfile: { showProfileEdit = true }
                    )
                    StatsSummarySection(
                        todayScore: todayScore,
                        weeklyAverage: weeklyAverage,
                        currentStreak: currentStreak,
                        monthlyAverage: viewModel.monthlyAverage,
                        statsDestination: StatsView(
                            scoreService: appServices.scoreService,
                            userService: appServices.userService
                        )
                    )
                    CalendarSectionView(
                        displayedMonth: $viewModel.displayedMonth,
                        entryForDate: { viewModel.entry(for: $0) },
                        previousMonth: { viewModel.previousMonth() },
                        nextMonth: { viewModel.nextMonth() },
                        onSelectDate: { date in handleCalendarTap(date) }
                    )
                    GuestbookSectionView(
                        messages: viewModel.guestbookMessages,
                        composeText: $viewModel.guestbookComposeText,
                        isPosting: viewModel.isPostingGuestbook,
                        onSubmit: { Task { await viewModel.postGuestbookMessage() } }
                    )
                } else if !viewModel.isLoading {
                    Text("Sign in to see your page")
                        .font(AppTypography.body())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    ProgressView()
                        .padding(.vertical, 60)
                }
            }
            .padding(.top, DesignTokens.spacingLG)
            .padding(.bottom, 32)
        }
        .background(DesignTokens.backgroundColor)
        .environment(\.colorScheme, .dark)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView(
                username: viewModel.currentUser?.username ?? "",
                bio: viewModel.currentUser?.bio ?? "",
                onSave: { newName, newBio in
                    Task {
                        await appServices.userService.updateUsername(newName)
                        await appServices.userService.updateBio(newBio)
                        await viewModel.load()
                    }
                }
            )
        }
        .sheet(item: $calendarRoute) { route in
            switch route {
            case .detail(let date, let entry):
                CalendarDayDetailSheet(
                    date: date,
                    entry: entry,
                    onEdit: {
                        calendarRoute = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            calendarRoute = .input(date)
                        }
                    },
                    onDelete: {
                        calendarRoute = nil
                        Task { await viewModel.deleteScore(for: date) }
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            case .input(let date):
                ScoreHomeView(
                    scoreService: appServices.scoreService,
                    userService: appServices.userService,
                    targetDate: date
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .scoorScoreStoreDidChange)) { _ in
            Task { await viewModel.load() }
        }
    }

    private func handleCalendarTap(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        if day > today { return }
        if let entry = viewModel.entry(for: day) {
            calendarRoute = .detail(day, entry)
        } else {
            calendarRoute = .input(day)
        }
    }

    // MARK: - Stats summary helpers (Stats 탭이 MyPage로 흡수되며 추가됨)

    /// 오늘 점수 — viewModel의 entry 인덱스에서 직접 조회.
    private var todayScore: Int? {
        viewModel.entry(for: Date())?.score
    }

    /// 직전 7일 중 입력된 날들의 평균.
    private var weeklyAverage: Int? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var scores: [Int] = []
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: -i, to: today),
               let entry = viewModel.entry(for: d) {
                scores.append(entry.score)
            }
        }
        guard !scores.isEmpty else { return nil }
        return Int(round(Double(scores.reduce(0, +)) / Double(scores.count)))
    }

    /// 오늘부터 거꾸로 entry가 끊기지 않고 연속된 일 수.
    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while viewModel.entry(for: day) != nil {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}

enum CalendarRoute: Identifiable {
    case detail(Date, ScoreEntry)
    case input(Date)

    var id: String {
        switch self {
        case .detail(let d, _): return "detail-\(d.timeIntervalSince1970)"
        case .input(let d): return "input-\(d.timeIntervalSince1970)"
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let username: String
    var bio: String? = nil
    let monthlyAverage: Int?
    var onEditProfile: (() -> Void)? = nil

    private var trimmedBio: String? {
        guard let bio = bio?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty else { return nil }
        return bio
    }

    var body: some View {
        HStack(alignment: .top) {
            Button {
                onEditProfile?()
            } label: {
                HStack(spacing: DesignTokens.spacingMD) {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.primaryColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DesignTokens.primaryColor)

                        // Edit badge
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignTokens.primaryColor)
                            .background(Circle().fill(DesignTokens.backgroundColor).padding(-2))
                            .offset(x: 18, y: 18)
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                        ScoorLogo(size: 20, variant: .white)
                        Text("@\(username)")
                            .font(AppTypography.bodySmall())
                            .foregroundStyle(DesignTokens.textSecondary)
                        if let trimmedBio {
                            Text(trimmedBio)
                                .font(AppTypography.bodySmall())
                                .foregroundStyle(DesignTokens.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .accessibilityIdentifier("profile-bio-text")
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit-profile-button")

            Spacer()

            if let avg = monthlyAverage {
                VStack(alignment: .trailing, spacing: DesignTokens.spacingXS) {
                    Text("\(avg)")
                        .font(AppTypography.title())
                        .foregroundStyle(DesignTokens.primaryColor)
                        .italic()
                    Text("MONTHLY AVG")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, DesignTokens.spacingXXL)
    }
}

// MARK: - Calendar Section (score-colored grid)

struct CalendarSectionView: View {
    @Binding var displayedMonth: Date
    let entryForDate: (Date) -> ScoreEntry?
    let previousMonth: () -> Void
    let nextMonth: () -> Void
    var onSelectDate: ((Date) -> Void)? = nil

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let firstWeekday = calendar.component(.weekday, from: first) // 1 = Sun
        let leadingBlanks = firstWeekday - 1
        var result: [Date?] = (0..<leadingBlanks).map { _ in nil }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: first) {
                result.append(date)
            }
        }
        let remainder = result.count % 7
        if remainder != 0 {
            result.append(contentsOf: (0..<(7 - remainder)).map { _ in nil as Date? })
        }
        return result
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(DesignTokens.primaryColor)
                        .padding(DesignTokens.spacingSM)
                        .background(DesignTokens.surfaceLight)
                        .clipShape(Circle())
                }

                Spacer()
                Text(monthTitle)
                    .font(AppTypography.sectionTitle())
                    .foregroundStyle(DesignTokens.textPrimary)
                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(DesignTokens.primaryColor)
                        .padding(DesignTokens.spacingSM)
                        .background(DesignTokens.surfaceLight)
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 0) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                    Text(day)
                        .font(AppTypography.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: DesignTokens.spacingSM) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let entry = entryForDate(date)
                        let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
                        Button {
                            guard !isFuture else { return }
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            onSelectDate?(date)
                        } label: {
                            CalendarDayCell(
                                date: date,
                                score: entry?.score,
                                hasReason: entry?.reason.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false,
                                isInteractive: !isFuture
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                        .accessibilityLabel(accessibilityLabel(for: date, entry: entry))
                        .accessibilityIdentifier("calendar-day-\(calendar.component(.day, from: date))")
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(DesignTokens.spacingXL)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignTokens.spacingXXL)
    }

    private func accessibilityLabel(for date: Date, entry: ScoreEntry?) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        let dayLabel = f.string(from: date)
        if let entry = entry {
            return "\(dayLabel), score \(entry.score). Tap to view details."
        }
        return "\(dayLabel), no entry. Tap to add."
    }
}

struct CalendarDayCell: View {
    let date: Date
    let score: Int?
    var hasReason: Bool = false
    var isInteractive: Bool = true

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    // Heatmap fill — deeper red as score increases
    private var fillColor: Color {
        guard let score = score else {
            return DesignTokens.surfaceLight.opacity(0.6)
        }
        let intensity = Double(score) / 100.0
        return DesignTokens.primaryColor.opacity(0.12 + intensity * 0.55)
    }

    var body: some View {
        let day = calendar.component(.day, from: date)
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 11, weight: score != nil ? .semibold : .regular))
                    .foregroundStyle(dayTextColor)

                if let score = score {
                    Text("\(score)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(ScoreTone.from(score: score).primary)
                } else {
                    // empty placeholder so height stays consistent
                    Color.clear.frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall)
                    .stroke(isToday ? DesignTokens.primaryColor : .clear, lineWidth: 1.5)
            )
            .opacity(isInteractive ? 1.0 : 0.35)

            if hasReason, score != nil {
                Circle()
                    .fill(DesignTokens.primaryColor)
                    .frame(width: 5, height: 5)
                    .padding(3)
            }
        }
        .contentShape(Rectangle())
    }

    private var dayTextColor: Color {
        if score != nil { return DesignTokens.textPrimary }
        return DesignTokens.textSecondary.opacity(0.6)
    }
}

// MARK: - Calendar Day Detail Sheet

struct CalendarDayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let entry: ScoreEntry
    let onEdit: () -> Void
    var onDelete: () -> Void = {}

    @State private var showDeleteConfirm = false

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date).uppercased()
    }

    private var hasReason: Bool {
        guard let r = entry.reason else { return false }
        return !r.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(dateLine)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DesignTokens.surfaceLight)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ScoorPalette.hairline, lineWidth: 0.5))
                }
                .accessibilityLabel("닫기")
            }
            .padding(.horizontal, DesignTokens.spacingXXL)
            .padding(.top, DesignTokens.spacingLG)

            Spacer(minLength: 0)

            VStack(spacing: DesignTokens.spacingMD) {
                Text("\(entry.score)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundStyle(ScoreTone.from(score: entry.score).primary)
                    .shadow(color: ScoreTone.from(score: entry.score).primary.opacity(0.4), radius: 20)

                Text("DAILY SCORE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(DesignTokens.textSecondary)
            }

            if hasReason {
                Text(entry.reason ?? "")
                    .font(AppTypography.body())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.textPrimary)
                    .padding(DesignTokens.spacingLG)
                    .frame(maxWidth: .infinity)
                    .background(DesignTokens.surfaceLight)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                            .stroke(ScoorPalette.hairline, lineWidth: 0.5)
                    )
                    .padding(.horizontal, DesignTokens.spacingXXL)
                    .padding(.top, DesignTokens.spacingXL)
            }

            Spacer(minLength: 0)

            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                    Text("수정하기")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule().fill(DesignTokens.primaryColor)
                )
                .shadow(color: DesignTokens.primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, DesignTokens.spacingXXL)

            Button(role: .destructive, action: { showDeleteConfirm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("삭제하기")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryColor)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .accessibilityLabel("삭제하기")
            .accessibilityIdentifier("delete-score-button")
            .padding(.horizontal, DesignTokens.spacingXXL)
            .padding(.top, 4)
            .padding(.bottom, DesignTokens.spacingXXL)
        }
        .background(ScoorPalette.bgBase)
        .environment(\.colorScheme, .dark)
        .confirmationDialog(
            "이 날의 점수를 삭제할까요?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                dismiss()
                onDelete()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제하면 되돌릴 수 없습니다.")
        }
    }
}

// MARK: - Guestbook Section

struct GuestbookSectionView: View {
    let messages: [GuestbookMessageDisplay]
    @Binding var composeText: String
    let isPosting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.primaryColor)
                    Text("Guestbook")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
                Text("\(messages.count) Entries")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.64, green: 0.64, blue: 0.68))
            }
            .padding(.horizontal, 16)

            HStack(spacing: 4) {
                TextField("방명록에 한 줄 남겨보세요...", text: $composeText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .padding(.leading, 16)
                    .padding(.vertical, 10)
                Button(action: onSubmit) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(DesignTokens.primaryColor)
                        .clipShape(Circle())
                }
                .disabled(composeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                .padding(.trailing, 4)
            }
            .background(ScoorPalette.bgRaised)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(ScoorPalette.hairline, lineWidth: 0.5))
            .padding(.horizontal, 16)

            if messages.isEmpty {
                Text("아직 방명록이 없어요. 첫 글을 남겨보세요!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                VStack(spacing: 16) {
                    ForEach(messages) { msg in
                        GuestbookMessageRow(message: msg)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }
}

struct GuestbookMessageRow: View {
    let message: GuestbookMessageDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(DesignTokens.primaryColor.opacity(0.12))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(DesignTokens.primaryColor.opacity(0.6))
                        )
                    Text(message.authorName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.primary)
                    if message.isPrivate {
                        Text("PRIVATE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(DesignTokens.primaryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.primaryColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Image(systemName: message.isPrivate ? "lock.fill" : "globe")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.82, green: 0.82, blue: 0.84))
            }

            Text(message.content)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.38))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(relativeTime(message.createdAt))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.64, green: 0.64, blue: 0.68))
                Spacer()
                HStack(spacing: 12) {
                    Button("Reply") {}
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignTokens.primaryColor)
                    if !message.isPrivate {
                        Button("Delete") {}
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(red: 0.64, green: 0.64, blue: 0.68))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.isPrivate ? ScoorPalette.bgFloat : ScoorPalette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(message.isPrivate ? ScoorPalette.inkTertiary : DesignTokens.primaryColor)
                .frame(width: 3)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Stats Summary Section
//
// Stats 탭이 사라지면서 그 핵심 수치(오늘 / 7일 평균 / 연속 / 이번 달 평균)를
// MyPage 안의 ‘개인 감정 대시보드’ 섹션으로 가져온다.
// 자세한 일/주/월 분석 화면은 NavigationLink → StatsView 로 진입.

struct StatsSummarySection<Destination: View>: View {
    let todayScore: Int?
    let weeklyAverage: Int?
    let currentStreak: Int
    let monthlyAverage: Int?
    let statsDestination: Destination

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            HStack {
                Text("STATS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                NavigationLink(destination: statsDestination) {
                    HStack(spacing: 4) {
                        Text("더 보기")
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DesignTokens.primaryColor)
                }
                .buttonStyle(.plain)
            }

            let columns = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]
            LazyVGrid(columns: columns, spacing: 10) {
                miniCard(label: "오늘",     value: todayScore.map(String.init)     ?? "—", subtitle: "TODAY")
                miniCard(label: "7일 평균",  value: weeklyAverage.map(String.init)  ?? "—", subtitle: "7-DAY AVG")
                miniCard(label: "연속",     value: "\(currentStreak)",              subtitle: "STREAK · 일")
                miniCard(label: "이번 달",   value: monthlyAverage.map(String.init) ?? "—", subtitle: "MONTH AVG")
            }
        }
        .padding(DesignTokens.spacingXL)
        .background(DesignTokens.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusCard, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
        .padding(.horizontal, DesignTokens.spacingXXL)
    }

    @ViewBuilder
    private func miniCard(label: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(DesignTokens.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(DesignTokens.primaryColor)
                .italic()
                .monospacedDigit()
            Text(subtitle)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(DesignTokens.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ScoorPalette.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    let username: String
    var bio: String = ""
    var onSave: (_ username: String, _ bio: String) -> Void = { _, _ in }

    @State private var editName: String = ""
    @State private var editUsername: String = ""
    @State private var editBio: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Avatar edit
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(DesignTokens.primaryColor.opacity(0.15))
                                .frame(width: 88, height: 88)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 36, weight: .semibold))
                                        .foregroundStyle(DesignTokens.primaryColor)
                                )

                            Circle()
                                .fill(DesignTokens.primaryColor)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                )
                                .offset(x: 4, y: 4)
                        }

                        Text("프로필 사진 변경")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DesignTokens.primaryColor)
                    }
                    .padding(.top, 8)

                    // Fields
                    VStack(spacing: 0) {
                        editField(label: "이름", text: $editName, placeholder: "이름을 입력하세요")
                        Divider().background(ScoorPalette.hairline)
                        editField(label: "사용자명", text: $editUsername, placeholder: "@username")
                        Divider().background(ScoorPalette.hairline)
                        editField(label: "소개", text: $editBio, placeholder: "나를 한 줄로 표현해보세요", identifier: "profile-bio-field")
                    }
                    .background(ScoorPalette.bgRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ScoorPalette.hairline, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)

                    // Extra info fields
                    VStack(spacing: 0) {
                        staticField(label: "이메일", value: "비공개")
                        Divider().background(ScoorPalette.hairline)
                        staticField(label: "성별", value: "설정 안 함")
                    }
                    .background(ScoorPalette.bgRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ScoorPalette.hairline, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 8)
            }
            .background(ScoorPalette.bgBase)
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ScoorPalette.bgBase, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        onSave(editUsername, editBio)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            editUsername = username
            editBio = bio
        }
        .presentationDetents([.large])
    }

    private func editField(label: String, text: Binding<String>, placeholder: String, identifier: String? = nil) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
                .frame(width: 72, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .accessibilityIdentifier(identifier ?? "")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func staticField(label: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(ScoorPalette.inkTertiary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Previews

#Preview("My Page (with data)") {
    let (score, user, guestbook) = PreviewData.makePreviewServices()
    let services = AppServices(scoreService: score, userService: user, guestbookService: guestbook)
    return NavigationStack {
        MyPageView(scoreService: score, userService: user, guestbookService: guestbook)
            .environmentObject(services)
    }
}

#Preview("My Page (empty)") {
    NavigationStack {
        MyPageView(
            scoreService: MockScoreService(),
            userService: MockUserService(),
            guestbookService: MockGuestbookService()
        )
        .environmentObject(AppServices())
    }
}
