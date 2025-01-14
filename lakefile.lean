import Lake
open Lake DSL

package «subverso» where
  -- add package configuration options here

lean_lib SubVersoCompat where
  srcDir := "src/compat"
  roots := #[`SubVerso.Compat]

lean_lib SubVersoHighlighting where
  srcDir := "src/highlighting"
  roots := #[`SubVerso.Highlighting]

lean_lib SubVersoExamples where
  srcDir := "src/examples"
  roots := #[`SubVerso.Examples]

@[default_target]
lean_exe «subverso-tests» where
  root := `Tests
  supportInterpreter := true

@[default_target]
lean_exe «subverso-extract» where
  root := `Extract
  supportInterpreter := true

module_facet examples mod : FilePath := do
  let ws ← getWorkspace
  let some extract ← findLeanExe? `«subverso-extract»
    | error "The subverso-extract executable was not found"

  let exeJob ← extract.exe.fetch
  let modJob ← mod.olean.fetch

  let buildDir := ws.root.buildDir
  let hlFile := mod.filePath (buildDir / "examples") "json"

  exeJob.bindAsync fun exeFile exeTrace =>
    modJob.bindSync fun _oleanPath modTrace => do
      let depTrace := mixTrace exeTrace modTrace
      let trace ← buildFileUnlessUpToDate hlFile depTrace do
        logStep s!"Exporting highlighted example JSON for '{mod.name}'"
        proc {
          cmd := exeFile.toString
          args := #[mod.name.toString, hlFile.toString]
          env := ← getAugmentedEnv
        }
      pure (hlFile, trace)

library_facet examples lib : FilePath := do
  let ws ← getWorkspace
  let mods ← lib.modules.fetch
  let moduleJobs ← BuildJob.mixArray <| ← mods.mapM (fetch <| ·.facet `examples)
  let buildDir := ws.root.buildDir
  let hlDir := buildDir / "examples"
  moduleJobs.bindSync fun () trace => do
    pure (hlDir, trace)

package_facet examples pkg : FilePath := do
  let ws ← getWorkspace
  let libs := pkg.leanLibs
  let libJobs ← BuildJob.mixArray <| ← libs.mapM (fetch <| ·.facet `examples)
  let buildDir := ws.root.buildDir
  let hlDir := buildDir / "examples"
  libJobs.bindSync fun () trace => do
    logInfo s!"Highlighted code written to '{hlDir}'"
    pure (hlDir, trace)
