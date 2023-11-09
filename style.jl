
# format_citation #############################################################

function DocumenterCitations.format_citation(style::Val{:thesis}, cit::DocumenterCitations.CitationLink, entries, citations)
    DocumenterCitations.format_labeled_citation(style, cit, entries, citations; sort_and_collapse=true)
end


function DocumenterCitations.citation_label(::Val{:thesis}, entry, citations; notfound="?")
    key = replace(entry.id, "*" => "_")
    try
        return "$(citations[key])"
    catch exc
        @warn "citation_label: $(repr(key)) not found in `citations`. Using $(repr(notfound))."
        return notfound
    end
end


# format_bibliography_reference ###############################################

using Dates

function DocumenterCitations.format_bibliography_reference(style::Val{:thesis}, entry)
    namesfmt=:last
    urldate_accessed_on = "(accessed on "
    urldate_fmt  = Dates.default_format(Date)
    authors      = DocumenterCitations.format_names(entry; names=namesfmt)
    title        = '"'*DocumenterCitations.format_title(entry; italicize=false, link_url=false)*'"'
    published_in = DocumenterCitations.format_published_in(entry)
    eprint       = DocumenterCitations.format_eprint(entry)
    urldate      = DocumenterCitations.format_urldate(entry; accessed_on=urldate_accessed_on, fmt=urldate_fmt)
    if !isempty(urldate)
        urldate *= ')'
    end
    url          = DocumenterCitations.linkify(entry.access.url, entry.access.url)
    note         = DocumenterCitations.format_note(entry)
    parts = String[]
    for part in (authors, title, url, published_in, eprint, urldate, note)
        if !isempty(part)
            push!(parts, part)
        end
    end
    mdtext = DocumenterCitations._join_bib_parts(parts)
    return mdtext
end


# format_bibliography_label ###################################################

function DocumenterCitations.format_bibliography_label(
    style::Val{:thesis},
    entry,
    citations
)
    key = replace(entry.id, "*" => "_")
    i = get(citations, key, 0)
    if i == 0
        i = length(citations) + 1
        citations[key] = i
        @debug "Mark $key as cited ($i) because it is rendered in a bibliography"
    end
    label = DocumenterCitations.citation_label(style, entry, citations)
    return "[$label]"
end


# bib_html_list_style #########################################################

DocumenterCitations.bib_html_list_style(::Val{:thesis}) = :dl


# bib_sorting #################################################################

DocumenterCitations.bib_sorting(::Val{:thesis}) = :citation
