# Line icons for the Music controls (24-unit viewBox, round caps). Used by the mockups and rendered to PNG for the TV.
ICONS = {
 "play": '<path d="M7 4.5v15l12-7.5z" fill="currentColor" stroke="none"/>',
 "pause": '<rect x="6" y="4.5" width="4" height="15" rx="1" fill="currentColor" stroke="none"/><rect x="14" y="4.5" width="4" height="15" rx="1" fill="currentColor" stroke="none"/>',
 "prev": '<path d="M18 5v14L8 12z" fill="currentColor" stroke="none"/><path d="M6 5v14"/>',
 "next": '<path d="M6 5v14l10-7z" fill="currentColor" stroke="none"/><path d="M18 5v14"/>',
 "shuffle": '<path d="M3 7h3.5c2.5 0 3.7 1.4 5 3.5l1 1.6c1.3 2.1 2.5 3.9 5 3.9H21"/><path d="M3 17h3.5c1.6 0 2.7-.6 3.6-1.6"/><path d="M14.4 8.6c.9-1 2-1.6 3.6-1.6H21"/><path d="M18.5 4.5 21 7l-2.5 2.5"/><path d="M18.5 14.5 21 17l-2.5 2.5"/>',
 "repeat": '<path d="M4 11V9a3 3 0 0 1 3-3h12"/><path d="M16 3l3 3-3 3"/><path d="M20 13v2a3 3 0 0 1-3 3H5"/><path d="M8 21l-3-3 3-3"/>',
 "cover": '<rect x="4" y="4" width="16" height="16" rx="2"/><circle cx="12" cy="12" r="3.5"/><circle cx="12" cy="12" r=".6" fill="currentColor"/>',
 "viz": '<path d="M4 14v-4M8 18V6M12 15V9M16 20V4M20 13v-2"/>',
 "fire": '<path d="M12 21c-3.9 0-6.5-2.6-6.5-6 0-3.2 2.3-5.2 3.6-7.6.4 1.6 1.2 2.6 2.4 3.2-.2-2.9 1-5.4 3-7.1.3 3 2.2 4.8 3.4 6.8.8 1.3 1.1 2.6 1.1 4.2 0 3.6-3 6.5-7 6.5z"/><path d="M12 21c-1.6 0-2.7-1.1-2.7-2.6 0-1.5 1.3-2.4 2.7-4.4 1.4 2 2.7 2.9 2.7 4.4 0 1.5-1.1 2.6-2.7 2.6z"/>',
 "request": '<path d="M12 4v11"/><path d="M7.5 10.5 12 15l4.5-4.5"/><path d="M5 19h14"/>',
 "more": '<circle cx="9" cy="17" r="2.5"/><path d="M11.5 17V5l7-1.5v3L11.5 8"/><path d="M17 13l1 2 2 .3-1.5 1.4.4 2.1-1.9-1-1.9 1 .4-2.1-1.5-1.4 2-.3z" fill="currentColor" stroke="none"/>',
 "expand": '<path d="M14 4h6v6M10 20H4v-6M20 4l-7 7M4 20l7-7"/>',
 "collapse": '<path d="M4 14h6v6M20 10h-6V4M10 14l-7 7M14 10l7-7"/>',
 "check": '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
 "clock": '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
 "search": '<circle cx="10.5" cy="10.5" r="6"/><path d="m15 15 5 5"/>',
 "cast": '<path d="M3 17a4 4 0 0 1 4 4M3 13a8 8 0 0 1 8 8M3 9a12 12 0 0 1 12 12"/><path d="M3 6V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-3"/>',
 "speaker": '<rect x="6" y="3" width="12" height="18" rx="2.5"/><circle cx="12" cy="14.5" r="3.2"/><circle cx="12" cy="7.5" r="1" fill="currentColor"/>',
 "tv": '<rect x="3" y="5" width="18" height="12" rx="2"/><path d="M8 21h8M12 17v4"/>',
 "house": '<path d="M3.5 11 12 4l8.5 7"/><path d="M6 9.5V20h12V9.5"/><path d="M10 20v-5h4v5"/>',
 "timing": '<circle cx="12" cy="13" r="7.5"/><path d="M12 9v4l2.5 2"/><path d="M9.5 2.5h5"/>',
 "queue": '<path d="M4 6h12M4 12h12M4 18h7"/><path d="M18 14v6l4-3z" fill="currentColor"/>',
 "close": '<path d="M6 6l12 12M18 6L6 18"/>',
}
def svg(name, size=30, color="currentColor", sw=2):
    return f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" style="display:block">{ICONS[name]}</svg>'
