#!/bin/awk -f

function release_subst(rel) {
    rel = tolower(rel);
    if(match(rel, "^rhel.*"))
        return "centos"

    return rel;
}

BEGIN {
    if(os_type == "" || os_ver == "") {
        print "Missing arguments";
        exit 1;
    }

    os_type = release_subst(os_type);
    os_ver = os_ver;
    print "Checking relevancy for " os_type " " os_ver;
}

match($0, /\"Releases:\s*(.*)\"/, m) {
    split(m[1], items, /\s+/);
}

END {
    for(i in items) {
        if(match(items[i], /([-])?([^0-9]+)([0-9]+)/, release)) {
            exclude = (release[1] != "") ? 1 : 0;
            rel_type = release_subst(release[2]);
            rel_ver = release[3];
            print rel_type " " rel_ver " " ((exclude) ? "exclude" : "ok")
            if(rel_type == os_type && rel_ver == os_ver && exclude)
                exit 1;
        }
    }

    exit 0;
}
