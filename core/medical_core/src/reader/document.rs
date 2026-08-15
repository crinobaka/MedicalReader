use mupdf::{Document as MuPdfDocument, Error};

use super::renderer::{render_page, RenderedPage};

pub struct Document {
    id: String,
    path: String,
    inner: MuPdfDocument,
}

pub struct SearchResult {
    pub page_index: u32,
    pub hit_count: u32,
    pub contexts: Vec<String>,
}

impl Document {
    pub fn open(id: String, path: String) -> Result<Self, Error> {
        let inner = MuPdfDocument::open(&path)?;

        Ok(Self {
            id,
            path,
            inner,
        })
    }

    pub fn id(&self) -> &str {
        &self.id
    }

    pub fn path(&self) -> &str {
        &self.path
    }

    pub fn page_count(&self) -> Result<u32, Error> {
        Ok(self.inner.page_count()? as u32)
    }

    pub fn render_page(
        &self,
        page_index: u32,
        dpi: u32,
    ) -> Result<RenderedPage, Error> {
        render_page(&self.inner, page_index, dpi)
    }
    pub fn search(
        &self,
        query: &str,
        max_results: u32,
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

            if hits.is_empty() {
                continue;
            }

            let text = page
                .text(mupdf::TextExtractOptions::default())
                .unwrap_or_default();

            let contexts = Self::build_search_contexts(
                &text,
                query,
            );

            results.push(SearchResult {
                page_index,
                hit_count: hits.len() as u32,
                contexts,
            });

            if results.len() >= max_results as usize {
                break;
            }
        }

        Ok(results)
    }

    fn build_search_contexts(
        text: &str,
        query: &str,
    ) -> Vec<String> {
        const MAX_CONTEXTS: usize = 3;
        const CONTEXT_RADIUS: usize = 80;

        if text.is_empty() || query.is_empty() {
            return Vec::new();
        }

        let mut contexts = Vec::new();

        let lower_text = text.to_lowercase();
        let lower_query = query.to_lowercase();

        let mut search_start = 0;

        while search_start < lower_text.len()
            && contexts.len() < MAX_CONTEXTS
        {
            let Some(relative_index) =
                lower_text[search_start..].find(&lower_query)
            else {
                break;
            };

            let match_start =
                search_start + relative_index;

            let match_end =
                match_start + lower_query.len();

            let context_start =
                match_start.saturating_sub(CONTEXT_RADIUS);

            let context_end =
                (match_end + CONTEXT_RADIUS)
                    .min(text.len());

            let mut context =
                text[context_start..context_end]
                    .replace('\n', " ")
                    .replace('\r', " ");

            context = context
                .split_whitespace()
                .collect::<Vec<_>>()
                .join(" ");

            if context_start > 0 {
                context = format!("…{context}");
            }

            if context_end < text.len() {
                context.push('…');
            }

            contexts.push(context);

            search_start = match_end;
        }

        contexts
    }
}