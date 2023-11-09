# Notes 12-06-2023

 * Fix overly long paths in output of `MyStructSpecified`
 * Move `mode=:sound` errors to appendix
 * fix colors of onehotbatch graphic

# Notes Meeting 17-03-2023

 * ~Julia always capitalized~
 * ~Subheadings capitalized~
 * ~'I' -> 'we'~ there were only two occurences of this in the entire thesis
 * ~'paper' -> 'work'/'thesis'~
 * Ziel: "Performance Guidelines"
 * Braucht Fragestellung! Welche Steps sind zu erledigen?
   * In der Introduction
   * Wir machen Guidelines
     * Guidelines types
     * Guidelines Memory Management
     * Weniger Dokumentation-mäßig
 * ~Reproducibility ans Ende~
 * ~@code_warntype output kürzen~
 * ~'garbage' -> memory management~ geändert, aber ein paar stellen haben noch immer "Garbage Collector" weil das ding nunmal so heißt..
 * ~Graphiken als PDF?~
    * No, because getting that in consistently is hard. I just cranked up the dpi to 300 and that fixed the blurriness.
 * ~Fix quotes "" -> ``''~
    * Check if this can be undone when producing HTML output
 * aktiv/passiv ok, evtl. ein paar Stellen später anpassen (späteres Meeting)
 * ~Name versions of HPC codes~
 * Backupreferenzen für sketchy parts später

## More ressources

 * https://glebbahmutov.com/blog/detecting-function-optimizations-in-v8/
  * unclear if useful, since the optimization model is even more opaque than Julia
 * https://mrale.ph/blog/2015/01/11/whats-up-with-monomorphism.html
  * Probably most useful/related, but not exactly
 * https://drops.dagstuhl.de/opus/volltexte/2018/9221/pdf/LIPIcs-ECOOP-2018-16.pdf
  * mentions type stability for optimization of python
 * https://dl.acm.org/doi/pdf/10.1145/800017.800542
  * Smalltalk paper by Peter Deutsch about optimization tricks like method address caching (which you can do in type stable code)
 * PProf, perf.. Am Ende referenzieren, wenn wir sie verwenden
 * https://dl.acm.org/doi/10.1145/3485527

