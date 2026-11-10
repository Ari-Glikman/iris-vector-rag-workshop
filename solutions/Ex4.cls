/// Exercise 4 - Build and test a RAG pipeline (slides 18-25).
/// Prompt: data/prompts/system_prompt.txt. The notebook exercises/ex4_rag.ipynb does the same in Python and can call this class.
/// The LLM is called from IRIS with %Net.HttpRequest; the API key: do ##class(Workshop.Util).SetKey("<workshop key>") first (or the notebook's first cell).
/// <p>Run: <code>do ##class(Workshop.Exercise.Ex4).Run()</code></p>
/// <p>TODO 4: BuildContext(). TODO 5: Ask().</p>
Class Workshop.Exercise.Ex4 Extends %RegisteredObject
{

/// One block per retrieved passage, separated by a blank line:
/// <pre>[vector-search §1] title (source: vector-search-guide.pdf)
/// passage text</pre>
/// The chunk ID in brackets is what the LLM will cite.
ClassMethod BuildContext(hits As %DynamicArray) As %String
{
    set text = "", iter = hits.%GetIterator()
    while iter.%GetNext(.i, .h) {
        set block = "["_h.%Get("chunk_id")_"] "_h.title_" (source: "_h.source_")"_$char(10)_h.content
        set text = text_$select(text = "": "", 1: $char(10, 10))_block
    }
    return text
}

/// Retrieve first, then generate. Returns {question, retrieval, reply, unknown_citations}.
ClassMethod Ask(question As %String, k As %Integer = 3, minScore As %String = "", show As %Boolean = 1) As %DynamicObject
{
    set retrieval = ##class(Workshop.Util).Search(question, k, minScore)
    set context = ..BuildContext(retrieval.hits)
    set userMsg = "Passages:"_$char(10, 10)_$select(context = "": "(no passages retrieved)", 1: context)_$char(10, 10)_"Question: "_question
    set reply = ##class(Workshop.Util).Complete(##class(Workshop.Util).SystemPrompt(), userMsg)
    set retrieved = "", iter = retrieval.hits.%GetIterator()
    while iter.%GetNext(.i, .h) {
        set retrieved = retrieved_$listbuild(h.%Get("chunk_id"))
    }
    set unknown = [], iter = reply.%Get("cited_chunk_ids").%GetIterator()
    while iter.%GetNext(.i, .cid) {
        if '$listfind(retrieved, cid) {
            do unknown.%Push(cid)
        }
    }
    set result = {"question": (question), "retrieval": (retrieval), "reply": (reply), "unknown_citations": (unknown)}
    if show {
        do ..Show(result)
    }
    return result
}

/// Print the answer next to its evidence.
ClassMethod Show(result As %DynamicObject)
{
    set reply = result.reply
    write !, "Q: ", result.question, !
    write "A: ", reply.answer, !
    write "   sufficient_evidence=", $select(reply.%Get("sufficient_evidence"): "true", 1: "false")
    write "  cited=", reply.%Get("cited_chunk_ids").%ToJSON(), "  (", reply.model, ", ", $fnumber(reply.%Get("latency_ms"), "", 0), " ms)", !
    if result.%Get("unknown_citations").%Size() {
        write "   WARNING cited but not retrieved: ", result.%Get("unknown_citations").%ToJSON(), !
    }
    set cited = reply.%Get("cited_chunk_ids").%ToJSON()
    set iter = result.retrieval.hits.%GetIterator()
    while iter.%GetNext(.i, .h) {
        write "   ", $select(cited [ (""""_h.%Get("chunk_id")_""""): "cited ", 1: "      "), $fnumber(h.score, "", 3), "  ", h.%Get("chunk_id"), "  ", $extract(h.content, 1, 90), "...", !
    }
}

/// For the notebook (Python calls this with iris.cls("Workshop.Exercise.Ex4").AskJSON(...)).
/// Returns the Ask() result as JSON, or {"error": "..."}.
ClassMethod AskJSON(question As %String, k As %Integer = 3, minScore As %String = "") As %String
{
    try {
        return ..Ask(question, k, minScore, 0).%ToJSON()
    } catch ex {
        return {"error": (ex.DisplayString())}.%ToJSON()
    }
}

ClassMethod Run() As %Status
{
    try {
        write "== Checkpoint: ", ##class(Workshop.Util).Checkpoint(4), !
        set status = ##class(Workshop.Util).LlmStatus()
        write "LLM: ", status, !

        write !, "== 1. Retrieval and context (TODO 4)", !
        set r = ##class(Workshop.Util).Search("How long do we keep lab backups?", 3)
        write ..BuildContext(r.hits), !

        write !, "== 2. The system prompt (data/prompts/system_prompt.txt, shared with Python)", !
        write ##class(Workshop.Util).SystemPrompt(), !

        set ready = ($extract(status, 1, 10) = "configured")
        if 'ready {
            write !, "LLM not configured - generation is skipped (nothing is mocked). Retrieval parts passed.", !
            write "Retrieval parts passed; generation NOT tested (LLM not configured).", !
            return $$$OK
        }
        write !, "== 3. Test it (TODO 5): read each answer next to its evidence", !
        set answerable = ..Ask("How long do we keep lab backups?")
        set paraphrase = ..Ask("For how many days are the nightly snapshots of a lab environment retained?")
        set unsupported = ..Ask("What uptime percentage does the platform guarantee in its SLA?")

        write !, "== 4. Add knowledge without retraining: the runbook (failed-imports §1)", !
        set question = "Where do failed imports go in our environment, and how long are they kept?"
        set before = ..Ask(question)
        write !, "ingested chunks: ", ##class(Workshop.Util).IngestRunbook(), !
        set after = ..Ask(question)
        do ##class(Workshop.Util).RemoveRunbook()
        write !, "runbook removed again (repeatable demo); chunks now: ", ##class(Workshop.Util).Scalar("SELECT COUNT(*) FROM Workshop.SupportChunks"), !

        // Success check
        set a = answerable.reply, u = unsupported.reply, b = before.reply, f = after.reply
        do ##class(Workshop.Util).Assert(..BuildContext(r.hits) [ "[backup-restore §2]", "BuildContext should contain [chunk_id] markers")
        do ##class(Workshop.Util).Assert(a.%Get("sufficient_evidence") && (a.answer [ "14"), "answerable question should say 14 days")
        do ##class(Workshop.Util).Assert(a.%Get("cited_chunk_ids").%ToJSON() [ "backup-restore §2", "answerable question should cite backup-restore §2")
        do ##class(Workshop.Util).Assert('u.%Get("sufficient_evidence") && (u.%Get("cited_chunk_ids").%Size() = 0), "unsupported question should cite nothing")
        do ##class(Workshop.Util).Assert('b.%Get("sufficient_evidence"), "before ingestion there is no evidence")
        do ##class(Workshop.Util).Assert((f.%Get("cited_chunk_ids").%ToJSON() [ "failed-imports §1") && (f.answer [ "11"), "after ingestion: cite failed-imports §1 and say 11 days")
        do ##class(Workshop.Util).Assert((answerable.%Get("unknown_citations").%Size() = 0) && (after.%Get("unknown_citations").%Size() = 0), "citations must be retrieved chunks")
        write !, "EXERCISE 4 PASSED", !
    } catch ex {
        return ##class(Workshop.Util).Report(ex)
    }
    return $$$OK
}

}
