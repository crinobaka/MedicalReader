use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

use crate::reader::document::Document;

use super::types::MedicalCorePage;

#[no_mangle]
pub extern "C" fn medical_core_hello() -> i32 {
    1
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_open_book(
    id: *const c_char,
    path: *const c_char,
) -> *mut Document {
    if id.is_null() || path.is_null() {
        return ptr::null_mut();
    }

    let id = match CStr::from_ptr(id).to_str() {
        Ok(value) => value.to_owned(),
        Err(_) => return ptr::null_mut(),
    };

    let path = match CStr::from_ptr(path).to_str() {
        Ok(value) => value.to_owned(),
        Err(_) => return ptr::null_mut(),
    };

    let document = match Document::open(id, path) {
        Ok(document) => document,
        Err(_) => return ptr::null_mut(),
    };

    Box::into_raw(Box::new(document))
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_close_book(
    handle: *mut Document,
) {
    if handle.is_null() {
        return;
    }

    drop(Box::from_raw(handle));
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_get_page_count(
    handle: *const Document,
    out_page_count: *mut u32,
) -> i32 {
    if handle.is_null() || out_page_count.is_null() {
        return -1;
    }

    let document = &*handle;

    match document.page_count() {
        Ok(page_count) => {
            *out_page_count = page_count;
            0
        }

        Err(_) => -1,
    }
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_render_page(
    handle: *const Document,
    page_index: u32,
    dpi: u32,
) -> *mut MedicalCorePage {
    if handle.is_null() {
        return ptr::null_mut();
    }

    let document = &*handle;

    let rendered_page = match document.render_page(page_index, dpi) {
        Ok(page) => page,
        Err(_) => return ptr::null_mut(),
    };

    MedicalCorePage::from_data(
        rendered_page.width,
        rendered_page.height,
        rendered_page.stride,
        rendered_page.components,
        rendered_page.data,
    )
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_free_page(
    page: *mut MedicalCorePage,
) {
    if page.is_null() {
        return;
    }

    let page = Box::from_raw(page);

    if !page.data.is_null() && page.data_len > 0 {
        let slice = std::slice::from_raw_parts_mut(
            page.data,
            page.data_len,
        );

        let _ = Box::from_raw(slice);
    }
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_search_book(
    handle: *const Document,
    query: *const c_char,
    max_results: u32,
) -> *mut c_char {
    if handle.is_null() || query.is_null() {
        return ptr::null_mut();
    }

    let document = &*handle;

    let query = match CStr::from_ptr(query).to_str() {
        Ok(value) => value,
        Err(_) => return ptr::null_mut(),
    };

    let results = match document.search(query, max_results) {
        Ok(results) => results,
        Err(_) => return ptr::null_mut(),
    };

    let payload = results
        .iter()
        .map(|result| {
            serde_json::json!({
                "pageIndex": result.page_index,
                "hitCount": result.hit_count,
                "contexts": result.contexts,
                "hits": result
                    .hits
                    .iter()
                    .map(|hit| {
                        serde_json::json!({
                            "x": hit.x,
                            "y": hit.y,
                            "width": hit.width,
                            "height": hit.height,
                        })
                    })
                    .collect::<Vec<_>>(),
            })
        })
        .collect::<Vec<_>>();
    
    let payload = match serde_json::to_string(&payload) {
        Ok(value) => value,
        Err(_) => return ptr::null_mut(),
    };

    match CString::new(payload) {
        Ok(value) => value.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn medical_core_free_string(
    value: *mut c_char,
) {
    if value.is_null() {
        return;
    }

    drop(CString::from_raw(value));
}