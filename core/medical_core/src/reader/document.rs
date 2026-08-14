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

            if !hits.is_empty() {
                results.push(SearchResult {
                    page_index,
                    hit_count: hits.len() as u32,
                });
            }

            if results.len() >= max_results as usize {
                break;
            }
        }

        Ok(results)
    }
}