use mupdf::{Document as MuPdfDocument, Error};

use super::renderer::{render_page, RenderedPage};

pub struct Document {
    id: String,
    path: String,
    inner: MuPdfDocument,
}

pub struct SearchHit {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

pub struct SearchResult {
    pub page_index: u32,
    pub hit_count: u32,
    pub contexts: Vec<String>,
    pub hits: Vec<SearchHit>,
}

impl Document {
    pub fn open(id: String, path: String) -> Result<Self, Error> {
        let inner = MuPdfDocument::open(&path)?;

        Ok(Self { id, path, inner })
    }

    pub fn id(&self) -> &str { &self.id }
    pub fn path(&self) -> &str { &self.path }

    pub fn page_count(&self) -> Result<u32, Error> {
        Ok(self.inner.page_count()? as u32)
    }

    pub fn render_page(&self, page_index: u32, dpi: u32) -> Result<RenderedPage, Error> {
        render_page(&self.inner, page_index, dpi)
    }

    pub fn outlines_json(&self) -> Result<String, Error> {
        fn map_outline(outline: &mupdf::Outline) -> serde_json::Value {
            serde_json::json!({
                "id": format!("pdf-outline-{}", outline.title),
                "name": outline.title,
                "page_start": outline.dest.as_ref().map(|dest| dest.loc.page_number + 1),
                "children": outline.down.iter().map(map_outline).collect::<Vec<_>>(),
            })
        }

        let outlines = self.inner.outlines()?;
        Ok(serde_json::to_string(
            &outlines.iter().map(map_outline).collect::<Vec<_>>(),
        ).unwrap_or_else(|_| "[]".to_string()))
    }

    pub fn search(
        &self,
        query: &str,
        max_results: u32,
        context_before: usize,
        context_after: usize,
    ) -> Result<Vec<SearchResult>, Error> {
        let query = query.trim();

        if query.is_empty() || max_results == 0 {
            return Ok(Vec::new());
        }

        let page_count = self.inner.page_count()? as u32;
        let mut results = Vec::new();

        for page_index in 0..page_count {
            let page = self.inner.load_page(page_index as i32)?;
            let hits = page.search(query, 32)?;

            if hits.is_empty() { continue; }

            let page_bounds = page.bounds()?;
            let page_width = page_bounds.width();
            let page_height = page_bounds.height();

            let search_hits = if page_width > 0.0 && page_height > 0.0 {
                hits.iter().map(|hit| {
                    let x0 = hit.ul.x.min(hit.ur.x).min(hit.ll.x).min(hit.lr.x);
                    let y0 = hit.ul.y.min(hit.ur.y).min(hit.ll.y).min(hit.lr.y);
                    let x1 = hit.ul.x.max(hit.ur.x).max(hit.ll.x).max(hit.lr.x);
                    let y1 = hit.ul.y.max(hit.ur.y).max(hit.ll.y).max(hit.lr.y);
                    let x = ((x0 - page_bounds.x0) / page_width).clamp(0.0, 1.0);
                    let y = ((y0 - page_bounds.y0) / page_height).clamp(0.0, 1.0);
                    let right = ((x1 - page_bounds.x0) / page_width).clamp(0.0, 1.0);
                    let bottom = ((y1 - page_bounds.y0) / page_height).clamp(0.0, 1.0);
                    SearchHit { x, y, width: (right - x).max(0.0), height: (bottom - y).max(0.0) }
                }).collect::<Vec<_>>()
            } else { Vec::new() };

            let text = page.text(mupdf::TextExtractOptions::default()).unwrap_or_default();
            let contexts = Self::build_search_contexts(&text, query, context_before, context_after);

            results.push(SearchResult { page_index, hit_count: hits.len() as u32, contexts, hits: search_hits });
            if results.len() >= max_results as usize { break; }
        }

        Ok(results)
    }

    fn build_search_contexts(text: &str, query: &str, context_before: usize, context_after: usize) -> Vec<String> {
        const MAX_CONTEXTS: usize = 3;
        if text.is_empty() || query.is_empty() { return Vec::new(); }

        let lower_text = text.to_lowercase();
        let lower_query = query.to_lowercase();
        let text_chars: Vec<char> = text.chars().collect();
        let lower_text_chars: Vec<char> = lower_text.chars().collect();
        let lower_query_chars: Vec<char> = lower_query.chars().collect();

        if lower_query_chars.is_empty() || lower_query_chars.len() > lower_text_chars.len() { return Vec::new(); }

        let mut contexts = Vec::new();
        let mut search_start = 0usize;

        while search_start < lower_text_chars.len() && contexts.len() < MAX_CONTEXTS {
            let mut match_start = None;
            let remaining = &lower_text_chars[search_start..];
            if remaining.len() >= lower_query_chars.len() {
                for offset in 0..=remaining.len() - lower_query_chars.len() {
                    let candidate = &remaining[offset..offset + lower_query_chars.len()];
                    if candidate == lower_query_chars.as_slice() {
                        match_start = Some(search_start + offset);
                        break;
                    }
                }
            }

            let Some(match_start) = match_start else { break; };
            let match_end = match_start + lower_query_chars.len();
            let context_start = match_start.saturating_sub(context_before);
            let context_end = (match_end + context_after).min(text_chars.len());
            let mut context = text_chars[context_start..context_end].iter().collect::<String>();
            context = context.replace('\n', " ").replace('\r', " ");
            context = context.split_whitespace().collect::<Vec<_>>().join(" ");
            if context_start > 0 { context = format!("…{context}"); }
            if context_end < text_chars.len() { context.push('…'); }
            contexts.push(context);
            search_start = match_end;
        }

        contexts
    }
}
