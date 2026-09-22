# Pagination Feature - Quick Start Guide

## What Changed?

Your app now fetches **ALL actors from A-Z** instead of limiting to just 60-250 actors. Results are displayed with **pagination controls** at the bottom.

---

## How Pagination Works

### Before (Old System)
```
Limited Query → 60 actors → Show All
```

### After (New System)
```
Fetch ALL → Filter/Search → Paginate → Show 40 per page
```

---

## User Experience

### Screen Layout
```
┌─────────────────────────────────┐
│  Welcome, User                  │
│  [Search...] [Filter Icon]      │
│  [Active Filter Chips...]       │
├─────────────────────────────────┤
│                                 │
│  [Actor Card] [Actor Card]      │
│  [Actor Card] [Actor Card]      │
│  [Actor Card] [Actor Card]      │
│  ...                            │
│                                 │
├─────────────────────────────────┤
│ Showing 1 - 40 of 245           │
│ [◀ Previous] [Page 1/7] [Next ▶]│
├─────────────────────────────────┘
```

---

## Pagination Controls

### Components
1. **Info Text**: "Showing X - Y of Z total"
2. **Previous Button**: Navigate to previous page (disabled on page 1)
3. **Page Indicator**: Shows current page / total pages
4. **Next Button**: Navigate to next page (disabled on last page)

### Button Behavior
- **Enabled**: Blue color, clickable
- **Disabled**: Gray color, non-clickable
- **Auto-Scroll**: Page scrolls to top when changed

---

## What Data Gets Fetched?

### Initial Load
- Fetches up to **1000 published actors** from Firestore
- Applied filters/search done on client-side
- No additional API calls when paginating

### Example with Filters
```
Total Published Actors: 500
Applied Filters (Gender: Female, Location: Hyderabad): 45
Pages at 40/page: 2 pages (40 + 5)
```

---

## Auto-Reset Behavior

Pagination automatically resets to **Page 1** when:
- ✓ User types in search bar
- ✓ User changes gender filter
- ✓ User changes location filter  
- ✓ User adds/removes language filter
- ✓ User adds/removes role/tag filter
- ✓ User clears all filters

**Why?** To show most relevant results from the beginning of the filtered set.

---

## Configuration (Optional)

### Change Items Per Page
Edit in `actor_search_provider.dart`:
```dart
/// Items per page for pagination.
final itemsPerPageProvider = StateProvider<int>((ref) => 40);  // Change 40 to desired number
```

### Change Max Actors to Fetch
Edit in `actor_search_provider.dart`:
```dart
const _initialFetchLimit = 1000;  // Change 1000 to desired limit
```

---

## Performance Impact

| Operation | Before | After |
|-----------|--------|-------|
| Initial Load | ~60 actors | ~1000 actors (once) |
| Pagination | N/A | Instant (no API call) |
| Search | Searches 60-250 | Searches all actors |
| Filter | On 60-250 | On all actors |

**Overall**: Slightly longer initial load, but much better search/filter results!

---

## Testing the Feature

### Quick Test Steps
1. Open app → Actor home screen
2. Scroll down → See pagination controls at bottom
3. Click "Next" → View next page (notice auto-scroll)
4. Type search query → Page resets to 1
5. Apply filters → Page resets to 1
6. Check "Showing X - Y of Z" → Verify correct count

### Example Searches to Try
- Search "Abhinaya" → Should find "Abhinaya Krishna"
- Filter by Female + Language: Telugu → See all matching actresses
- No filters → See all published actors paginated

---

## Key Files Modified

1. **`actor_search_provider.dart`**
   - Added: `currentPageProvider` (current page state)
   - Added: `itemsPerPageProvider` (page size)
   - Modified: `actorSearchProvider` (now returns paginated results)
   - New: `allFilteredActorsProvider` (fetches all filtered actors)
   - New: `totalActorsCountProvider` (total count for display)

2. **`actor_search_body.dart`**
   - Added: `_PaginationControls` widget (pagination UI)
   - Modified: Grid layout (added pagination controls)
   - Modified: Search/filter handlers (reset pagination)

---

## Troubleshooting

### "No pagination controls visible"
- Check if there are any actors to display
- Pagination only shows if total > items per page

### "Page shows fewer than 40 actors"
- Last page shows remaining items (normal behavior)
- Example: 245 total items ÷ 40 = Page 7 has only 5 items

### "Pagination resets when I don't expect it"
- Search/filter changes always reset to page 1 (intentional)
- Ensures user sees most relevant results first

---

## Future Enhancements

- [ ] Smooth infinite scroll instead of pagination buttons
- [ ] Jump to specific page input
- [ ] Customizable items per page dropdown
- [ ] Remember last viewed page (when navigating back)
- [ ] Server-side pagination if data exceeds 1000

