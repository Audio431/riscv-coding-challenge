#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Plugins/PassPlugin.h"
#include "llvm/Support/raw_ostream.h"
 
using namespace llvm;
 
namespace {
 
struct CountMemOps : PassInfoMixin<CountMemOps> {
  PreservedAnalyses run(Module &M, ModuleAnalysisManager &) {
    unsigned TotalLoads = 0, TotalStores = 0, TotalMemIntrinsics = 0;
 
    for (Function &F : M) {
      // Declarations (e.g. __memcpy_chk, llvm.objectsize) have no body to
      // count.
      if (F.isDeclaration())
        continue;
 
      unsigned Loads = 0, Stores = 0, MemIntrinsics = 0;
      for (BasicBlock &BB : F)
        for (Instruction &I : BB) {
          if (isa<LoadInst>(I))
            ++Loads;
          else if (isa<StoreInst>(I))
            ++Stores;
          else if (isa<MemIntrinsic>(I))
            ++MemIntrinsics;
        }
 
      errs() << F.getName() << ": " << Loads << " loads, " << Stores
             << " stores, " << MemIntrinsics << " mem intrinsics\n";
 
      TotalLoads += Loads;
      TotalStores += Stores;
      TotalMemIntrinsics += MemIntrinsics;
    }
 
    errs() << "total: " << TotalLoads << " loads, " << TotalStores
           << " stores, " << TotalMemIntrinsics << " mem intrinsics\n";
    return PreservedAnalyses::all();
  }
 
  // Module passes are not skipped for optnone functions, but this keeps the
  // pass unskippable if it is ever wrapped in an adaptor or run at -O0
  // pipelines that honor required-ness.
  static bool isRequired() { return true; }
};
 
} // namespace
 
extern "C" LLVM_ATTRIBUTE_WEAK ::llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, "count-mem-ops", LLVM_VERSION_STRING,
          [](PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](StringRef Name, ModulePassManager &MPM,
                   ArrayRef<PassBuilder::PipelineElement>) {
                  if (Name == "count-mem-ops") {
                    MPM.addPass(CountMemOps());
                    return true;
                  }
                  return false;
                });
          }};
}