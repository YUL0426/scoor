# Crimson Velocity Design System

### 1. Overview & Creative North Star
**Creative North Star: "The Pulse of Performance"**
Crimson Velocity is a high-energy, editorial-inspired design system built for performance tracking and personal growth. It moves away from the static, boxy feel of traditional utility apps, instead embracing a dynamic, rhythmic layout characterized by high-contrast typography, italicized accent numbers, and a bold use of vibrant reds against stark, clean surfaces. The system prioritizes speed and momentum through intentional asymmetry and a "digital journal" aesthetic.

### 2. Colors
The palette is dominated by a high-fidelity "Crimson Red" (#f42525), supported by a sophisticated range of warm neutrals.

*   **Primary Identity:** The use of #f42525 is aggressive and intentional, reserved for critical data points, active states, and call-to-action elements.
*   **The "No-Line" Rule:** Visual separation is achieved through tonal shifts (Surface to Surface Container Low) or through structural padding. Borders are strictly forbidden for sectioning unless they are the "Signature Edge" (e.g., the 4px vertical accent on guestbook entries).
*   **Surface Hierarchy:** 
    *   **Main Canvas:** White (#ffffff) or ultra-light gray (#f8f5f5).
    *   **Nesting:** Calendars and grouping modules use `surface_container_low` to create soft "wells" within the page.
*   **The "Glass & Gradient" Rule:** The navigation bar and floating backgrounds utilize an `ios-blur` (20px) to maintain context while adding depth. Subtle background blurs (primary/5) are used in corners to break the white-space rigidity.

### 3. Typography
The system uses **Plus Jakarta Sans** across all levels, leaning into its geometric but friendly letterforms.

*   **Typographic Rhythm:**
    *   **Display (1.875rem / 30px):** Used for primary metrics and hero values, often set in Black Italic to imply motion.
    *   **Headline (1.25rem - 1.5rem):** ExtraBold weight with tight tracking for a modern, editorial feel.
    *   **Body (0.875rem - 1rem):** Medium weight with 1.6x line height for readability.
    *   **Labels (10px):** Black weight, Uppercase, Tracking-widest (e.g., 0.1em). This creates a "technical stamp" look for metadata.
*   **Signature Styling:** Numerical values are treated as brand assets—frequently primary-colored and italicized.

### 4. Elevation & Depth
Elevation in Crimson Velocity is conveyed through "Tonal Stacking" rather than heavy drop shadows.

*   **The Layering Principle:** Depth is created by placing white components on top of `surface_container_low` backgrounds.
*   **Ambient Shadows:**
    *   **Low (Shadow-sm):** Used for interaction buttons and small cards to lift them slightly off the background.
    *   **High (Shadow-2xl):** Reserved for the main device container and the primary Floating Action Button (FAB).
*   **The "Ghost Border":** Where borders exist (e.g., input fields or module dividers), they use `zinc-200/50` (ultra-low opacity) to ensure the layout feels "open."

### 5. Components
*   **FAB (Floating Action Button):** A 56px circular button in Primary Red with a high-offset shadow (shadow-primary/40). It is the anchor of the screen's action.
*   **Progressive Cards:** Cards use a 1rem (16px) radius. They often feature a signature 4px left-border accent in Primary Red to denote "active" or "unread" status.
*   **The "Pulse" Input:** A pill-shaped search/input bar with an integrated trailing button.
*   **Metric Clusters:** High-contrast pairings of a 10px uppercase label with a 24px+ ExtraBold value.

### 6. Do's and Don'ts
*   **Do:** Use italics for numbers to emphasize performance and speed.
*   **Do:** Use uppercase, wide-tracked labels for secondary information.
*   **Do:** Leverage `backdrop-filter` on fixed navigation elements.
*   **Don't:** Use 1px black borders. Use tonal shifts or very soft grays instead.
*   **Don't:** Use rounded corners smaller than 1rem for main container elements.
*   **Don't:** Crowd the layout; use generous 24px-32px margins for an editorial feel.