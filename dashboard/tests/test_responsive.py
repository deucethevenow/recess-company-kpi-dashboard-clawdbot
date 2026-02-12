"""
Responsive design tests for KPI Dashboard.

Tests viewport behavior at desktop (1280), tablet (768), and mobile (375) widths.
Verifies hamburger menu, card layout, and content visibility across breakpoints.

Requires: pip install playwright pytest-playwright
Run: pytest tests/test_responsive.py -v --headed (for visual) or headless
"""

import re
import pytest
from playwright.sync_api import sync_playwright, expect

BASE_URL = "http://localhost:8503"
LOAD_TIMEOUT = 15_000  # Streamlit can be slow on first render


@pytest.fixture(scope="module")
def browser():
    """Launch a fresh browser for the test module."""
    with sync_playwright() as p:
        b = p.chromium.launch(headless=True)
        yield b
        b.close()


def _load_page(browser, width, height):
    """Create a new context at given viewport, navigate, and wait for content."""
    ctx = browser.new_context(viewport={"width": width, "height": height})
    page = ctx.new_page()
    page.goto(BASE_URL)
    # Wait for Streamlit to finish rendering the main content
    page.wait_for_selector("text=Company Health", timeout=LOAD_TIMEOUT)
    # Extra time for JS injection (hamburger) to run
    page.wait_for_timeout(2000)
    return page, ctx


# =========================================================================
# Desktop (1280x800)
# =========================================================================

class TestDesktop:
    """Tests at desktop viewport (1280x800)."""

    @pytest.fixture(autouse=True)
    def setup(self, browser):
        self.page, self.ctx = _load_page(browser, 1280, 800)
        yield
        self.ctx.close()

    def test_sidebar_visible(self):
        """Sidebar should be visible on desktop."""
        sidebar = self.page.locator('[data-testid="stSidebar"]')
        expect(sidebar).to_be_visible()

    def test_sidebar_has_nav_items(self):
        """Sidebar should contain navigation buttons."""
        sidebar = self.page.locator('[data-testid="stSidebar"]')
        expect(sidebar.get_by_text("Overview")).to_be_visible()
        expect(sidebar.get_by_text("CEO / Biz Dev")).to_be_visible()

    def test_no_hamburger_on_desktop(self):
        """Hamburger button should not be visible on desktop."""
        hamburger = self.page.locator("#mh-btn")
        if hamburger.count() > 0:
            expect(hamburger).to_be_hidden()

    def test_page_header_visible(self):
        """Page header should show on desktop."""
        expect(self.page.get_by_text("Company Overview")).to_be_visible()

    def test_revenue_cards_visible(self):
        """Revenue horizon cards should be visible."""
        expect(self.page.get_by_text("$7.93M").first).to_be_visible()

    def test_company_health_section(self):
        """Company Health section should render with metric cards."""
        expect(self.page.get_by_text("Company Health")).to_be_visible()
        expect(self.page.get_by_text("Take Rate", exact=True)).to_be_visible()
        expect(self.page.get_by_text("Demand NRR")).to_be_visible()

    def test_team_accountability_section(self):
        """Team Accountability cards should render with 2025 references."""
        expect(self.page.get_by_text("Team Accountability")).to_be_visible()
        # 16 of 17 people have both target > 0 and ref_2025
        # (Marketing has target=0 so no "Target:" prefix)
        expect(self.page.get_by_text(re.compile(r"Target:.*2025:"))).to_have_count(16)


# =========================================================================
# Tablet (768x1024)
# =========================================================================

class TestTablet:
    """Tests at tablet viewport (768x1024)."""

    @pytest.fixture(autouse=True)
    def setup(self, browser):
        self.page, self.ctx = _load_page(browser, 768, 1024)
        yield
        self.ctx.close()

    def test_content_visible(self):
        """Main content should be visible on tablet."""
        expect(self.page.get_by_text("Company Health")).to_be_visible()
        expect(self.page.get_by_text("Team Accountability")).to_be_visible()

    def test_revenue_cards_visible(self):
        """Revenue cards should render."""
        expect(self.page.get_by_text("$7.93M").first).to_be_visible()


# =========================================================================
# Mobile (375x812) — iPhone-sized
# =========================================================================

class TestMobile:
    """Tests at mobile viewport (375x812)."""

    @pytest.fixture(autouse=True)
    def setup(self, browser):
        self.page, self.ctx = _load_page(browser, 375, 812)
        yield
        self.ctx.close()

    def test_hamburger_visible(self):
        """Hamburger button should be visible on mobile."""
        hamburger = self.page.locator("#mh-btn")
        expect(hamburger).to_be_visible()
        expect(hamburger).to_have_text("☰")

    def test_sidebar_hidden_by_default(self):
        """Sidebar should be off-screen on mobile initial load."""
        sidebar = self.page.locator('[data-testid="stSidebar"]')
        # Sidebar exists in DOM but is transformed off-screen
        box = sidebar.bounding_box()
        # The sidebar should be positioned to the left of the viewport
        assert box is None or box["x"] + box["width"] <= 0, \
            f"Sidebar should be off-screen but bounding box is {box}"

    def test_hamburger_opens_sidebar(self):
        """Clicking hamburger should reveal sidebar."""
        hamburger = self.page.locator("#mh-btn")
        hamburger.click()
        self.page.wait_for_timeout(500)

        # Button should toggle to close icon
        expect(hamburger).to_have_text("✕")

        # Sidebar nav should be visible
        sidebar = self.page.locator('[data-testid="stSidebar"]')
        expect(sidebar.get_by_text("Overview")).to_be_visible()

    def test_hamburger_closes_sidebar(self):
        """Clicking close button should hide sidebar."""
        hamburger = self.page.locator("#mh-btn")
        # Open
        hamburger.click()
        self.page.wait_for_timeout(500)
        # Close
        hamburger.click()
        self.page.wait_for_timeout(500)

        expect(hamburger).to_have_text("☰")

    def test_backdrop_closes_sidebar(self):
        """Clicking backdrop should close the sidebar."""
        hamburger = self.page.locator("#mh-btn")
        hamburger.click()
        self.page.wait_for_timeout(500)

        # Click backdrop on the right side (outside the sidebar overlay)
        backdrop = self.page.locator("#mh-backdrop")
        box = backdrop.bounding_box()
        # Click near the right edge where sidebar doesn't cover
        backdrop.click(position={"x": box["width"] - 10, "y": box["height"] / 2}, force=True)
        self.page.wait_for_timeout(500)

        expect(hamburger).to_have_text("☰")

    def test_mobile_header_visible(self):
        """Mobile header should be visible showing Recess branding."""
        expect(self.page.get_by_text("Recess KPIs")).to_be_visible()

    def test_content_visible_on_mobile(self):
        """Main dashboard content should be visible."""
        expect(self.page.get_by_text("$7.93M").first).to_be_visible()
        expect(self.page.get_by_text("Company Health")).to_be_visible()

    def test_team_cards_have_2025_refs(self):
        """Team cards should show 2025 reference values."""
        expect(self.page.get_by_text("2025: $3.91M")).to_be_visible()
        expect(self.page.get_by_text("2025: 49%")).to_be_visible()


# =========================================================================
# Small Mobile (320x568) — iPhone SE
# =========================================================================

class TestSmallMobile:
    """Tests at small mobile viewport (320x568)."""

    @pytest.fixture(autouse=True)
    def setup(self, browser):
        self.page, self.ctx = _load_page(browser, 320, 568)
        yield
        self.ctx.close()

    def test_hamburger_visible(self):
        """Hamburger should show on small screens."""
        hamburger = self.page.locator("#mh-btn")
        expect(hamburger).to_be_visible()

    def test_content_not_cut_off(self):
        """Content should be accessible (scrollable)."""
        expect(self.page.get_by_text("Company Health")).to_be_visible()
