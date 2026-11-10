/// Exercise 3 - Measure exact search vs HNSW (slides 15-17).
/// Measure exact search vs the HNSW index on the benchmark tables built into the image (plans: exercises/ex3_index.sql).
/// <p>Run: <code>do ##class(Workshop.Exercise.Ex3).Run()</code></p>
/// <p>TODO 3: TimedQuery(). RecallAtK() is given: read it to see how recall is counted.</p>
Class Workshop.Exercise.Ex3 Extends %RegisteredObject
{

Parameter EXACT = "Workshop.BenchExact";

Parameter HNSW = "Workshop.BenchHNSW";

ClassMethod QuerySQL(table As %String, k As %Integer) As %String
{
    return "SELECT TOP "_(k \ 1)_" vec_id, VECTOR_DOT_PRODUCT(vec, TO_VECTOR(?, DOUBLE, 384)) AS score FROM "_table_" ORDER BY score DESC"
}

/// Run a prepared top-k statement with one query vector (string). Fills rows = n and rows(1..n) = $LISTBUILD(vec_id, score).
/// Returns the elapsed time in milliseconds for the database work ONLY (%Execute + reading the rows).
ClassMethod TimedQuery(stmt As %SQL.Statement, vec As %String, Output rows) As %Double
{
    kill rows
    set rows = 0
    // TODO 3: Add "set t0 = $zhorolog" before %Execute, and replace return "" with: return ($zhorolog - t0) * 1000
    set rs = stmt.%Execute(vec)
    while rs.%Next() {
        set rows = rows + 1, rows(rows) = $listbuild(rs.%GetData(1), +rs.%GetData(2))
    }
    return ""
}

/// recall@k (given): which share of the true top k did the index find? approx = $LISTBUILD of the vec_ids the index returned (best first).
/// exact = n and exact(1..n) = $LISTBUILD(vec_id, score), sorted by score (best first), n = k + 10 rows.
/// Any vector tied with the k-th exact score counts as correct.
ClassMethod RecallAtK(approx As %List, ByRef exact, k As %Integer, eps As %Double = 0.000000001) As %Double
{
    set kth = $list(exact(k), 2)
    for r = 1:1:exact {
        if $list(exact(r), 2) >= (kth - eps) {
            set ok($list(exact(r), 1)) = ""
        }
    }
    set hits = 0, n = $listlength(approx)
    if n > k {
        set n = k
    }
    for r = 1:1:n {
        if $data(ok($list(approx, r))) {
            set hits = hits + 1
        }
    }
    return hits / k
}

ClassMethod Run() As %Status
{
    try {
        set cfg = ##class(Workshop.Util).BenchConfig()   // the benchmark tables are built into the image
        set k = cfg.k, warmup = cfg.warmup
        write "dataset: ", cfg.%Get("n_vectors"), " synthetic vectors, dim=", cfg.dim, ", k=", k, ", warm-up=", warmup, !

        write !, "== 1. Two tables, identical vectors, one index", !
        for t = ..#EXACT, ..#HNSW {
            write t, ": ", ##class(Workshop.Util).Scalar("SELECT COUNT(*) FROM "_t), " rows", !
        }
        write "identical vectors among the first 500 ids: ", ##class(Workshop.Util).Scalar("SELECT COUNT(*) FROM "_..#EXACT_" e JOIN "_..#HNSW_" h ON e.vec_id = h.vec_id WHERE e.vec_id < 500 AND VECTOR_DOT_PRODUCT(e.vec, h.vec) > 0.9999999"), !
        write "index: CREATE INDEX HNSWIdx ON TABLE ", ..#HNSW, " (vec) AS HNSW(M=", cfg.%Get("hnsw_m"), ", efConstruction=", cfg.%Get("hnsw_ef_construction"), ", Distance='DotProduct')  -- build ", $fnumber(cfg.%Get("index_seconds"), "", 1), " s", !

        write !, "== Plans (EXPLAIN works with ? parameters from ObjectScript)", !
        for t = ..#EXACT, ..#HNSW {
            set plan = ##class(Workshop.Util).Scalar("EXPLAIN "_..QuerySQL(t, k))
            set uses(t) = (plan [ "HNSWIdx")
            write t, "  uses HNSW index: ", uses(t), !
            for n = 1:1:$length(plan, $char(10)) {
                set line = $zstrip($piece(plan, $char(10), n), "<>W")
                if ($extract(line, 1, 4) = "Read") || ($extract(line, 1, 4) = "Cost") {
                    write "     ", line, !
                }
            }
        }

        write !, "== 2./3. Measure (your TimedQuery, TODO 3): warm-up first, then alternate which table goes first", !
        for t = ..#EXACT, ..#HNSW {
            set stmt(t) = ##class(%SQL.Statement).%New()
            $$$ThrowOnError(stmt(t).%Prepare(..QuerySQL(t, k)))
        }
        set wide = ##class(%SQL.Statement).%New()
        $$$ThrowOnError(wide.%Prepare(..QuerySQL(..#EXACT, k + 10)))
        set rs = ##class(Workshop.Util).Query("SELECT q_no, vec FROM Workshop.BenchQueries ORDER BY q_no")
        while rs.%Next() {
            set q(rs.%Get("q_no")) = ##class(Workshop.Util).VectorToString(rs.%Get("vec"))
        }
        set last = $order(q(""), -1)
        for i = 0:1:(warmup - 1) {
            for t = ..#EXACT, ..#HNSW {
                do ..TimedQuery(stmt(t), q(i), .ignore)
            }
        }
        set n = 0
        for i = warmup:1:last {
            set n = n + 1
            set order = $select(i # 2: $listbuild(..#EXACT, ..#HNSW), 1: $listbuild(..#HNSW, ..#EXACT))
            for j = 1:1:2 {
                set t = $list(order, j)
                set lat(t, n) = ..TimedQuery(stmt(t), q(i), .rows)
                if t = ..#HNSW {
                    set approx = ""
                    for r = 1:1:rows {
                        set approx = approx_$listbuild($list(rows(r), 1))
                    }
                }
            }
            do ..TimedQuery(wide, q(i), .exactRows)
            set recall(n) = ..RecallAtK(approx, .exactRows, k)
        }

        write !, "== 4. Report what you measured", !
        write "table                  median ms   p95 ms   n", !
        for t = ..#EXACT, ..#HNSW {
            kill values
            merge values = lat(t)
            set med(t) = ##class(Workshop.Util).Median(.values)
            write t, $justify("", 23 - $length(t)), $justify($fnumber(med(t), "", 2), 10), $justify($fnumber(##class(Workshop.Util).Percentile(.values, 95), "", 2), 9), "   ", n, !
        }
        set sum = 0, min = 1, perfect = 0
        for r = 1:1:n {
            set sum = sum + recall(r)
            if recall(r) < min {
                set min = recall(r)
            }
            if recall(r) = 1 {
                set perfect = perfect + 1
            }
        }
        write "recall@", k, ": mean ", $fnumber(sum / n, "", 3), ", min ", $fnumber(min, "", 2), ", perfect on ", perfect, "/", n, " queries", !
        write "No speedup is promised: results depend on data size, hardware, cache state and index settings.", !

        // Success check
        set m = med(..#HNSW)
        do ##class(Workshop.Util).Assert((m '= "") && (+m = m) && (m > 0), "TimedQuery must return milliseconds")
        kill test
        set test = 4, test(1) = $listbuild(1, .9), test(2) = $listbuild(2, .8), test(3) = $listbuild(3, .7), test(4) = $listbuild(4, .6)
        do ##class(Workshop.Util).Assert(..RecallAtK($listbuild(1, 2, 3), .test, 3) = 1, "recall of a perfect result should be 1")
        do ##class(Workshop.Util).Assert(..RecallAtK($listbuild(5, 6, 7), .test, 3) = 0, "recall of a wrong result should be 0")
        set test(4) = $listbuild(4, .7)
        do ##class(Workshop.Util).Assert(..RecallAtK($listbuild(1, 2, 4), .test, 3) = 1, "a tie at the k-th score should count")
        do ##class(Workshop.Util).Assert(uses(..#HNSW) && 'uses(..#EXACT), "only the indexed table should use HNSWIdx")
        write !, "EXERCISE 3 PASSED", !
    } catch ex {
        return ##class(Workshop.Util).Report(ex)
    }
    return $$$OK
}

}
