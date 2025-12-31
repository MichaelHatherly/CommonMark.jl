function normalize_reference(str)
    if startswith(str, '[') && endswith(str, ']')
        str = chop(str; head = 1, tail = 1)
    end
    # Spec requires Unicode case fold (not just lowercase) for reference matching
    str = Base.Unicode.normalize(str, casefold = true)
    str = strip(replace(str, r"\s+" => ' '))
    return isempty(str) ? "[]" : str
end
