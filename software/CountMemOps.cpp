#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Plugins/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {

struct CountMemOps : PassInfoMixin<CountMemOps> {
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &) {
    errs() << "visiting " << F.getName() << "\n";
    return PreservedAnalyses::all();
  }

  static bool isRequired() { return true; }
};

} // namespace

extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "count-mem-ops", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, FunctionPassManager &FPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "count-mem-ops") {
                    FPM.addPass(CountMemOps());
                    return true;
                  }
                  return false;
                });
          }};
}