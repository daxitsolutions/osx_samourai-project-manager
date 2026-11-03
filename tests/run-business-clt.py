# Isolated business harness for macOS Command Line Tools; does not validate SwiftUI.
from pathlib import Path
import subprocess,sys,os
checkout=Path(__file__).resolve().parent.parent;run=Path(sys.argv[1]).resolve();os.chdir(checkout)
root=run/'Sources';root.mkdir(parents=True,exist_ok=True)
names='ActionModels ActivityIndex ActivityModels AppLocalization DecisionModels DeliverableModels EventModels GovernanceModels ImportProgressTracker MeetingModels MerlinProjectImportService ProjectModels RESTAPIModels ResourceImportService ResourceModels ResourceStore+Analytics ResourceStore+CRUD ResourceStore+Import ResourceStore+ImportReviewHelpers ResourceStore RiskImportService RiskModels SamouraiColorTheme SamouraiDatabase+Validation SamouraiModels SamouraiPersistence SamouraiPersistence+Recovery SamouraiStore+Recovery SamouraiStore+Demo SamouraiStore ScopeModels SharedTypes TestingModels'.split()
if (checkout/'Sources/SamouraiProjectManagerApp/Support/SamouraiBackup+Decoding.swift').exists():names.append('SamouraiBackup+Decoding')
for name in names:
 source=next(Path('Sources').rglob(name+'.swift'));body=source.read_text()
 if name=='AppLocalization':body=body.split('extension AppState {')[0]
 if name=='ImportProgressTracker':body=body.split('struct SamouraiImportProgressSheet: View {')[0]
 (root/source.name).write_text(body)
(root/'ResourceBundle.swift').write_text('import Foundation\nextension Bundle { static var module: Bundle { .main } }\n')
cache=str(run/'module-cache');framework='/Library/Developer/CommandLineTools/Library/Developer/Frameworks'
subprocess.run(['swiftc','-swift-version','6','-parse-as-library','-enable-testing','-emit-library','-emit-module','-module-name','SamouraiProjectManagerApp','-module-cache-path',cache,*[str(p) for p in root.glob('*.swift') if p.name != 'Runner.swift'],'-o',str(run/'libSamouraiProjectManagerApp.dylib')],check=True)
(root/'Runner.swift').write_text('import Testing\nimport Darwin\n@main struct TestRunner { static func main() async { let result: CInt = await Testing.__swiftPMEntryPoint(); exit(result) } }\n')
tests=[str(p) for p in Path('tests/SamouraiProjectManagerTests').glob('*.swift') if p.name!='RESTAPIAccessTests.swift']
subprocess.run(['swiftc','-swift-version','6','-parse-as-library','-module-cache-path',cache,'-F',framework,'-framework','Testing','-load-plugin-library','/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib','-I',str(run),'-L',str(run),'-lSamouraiProjectManagerApp','-Xlinker','-rpath','-Xlinker',str(run),'-Xlinker','-rpath','-Xlinker',framework,str(root/'Runner.swift'),*tests,'-o',str(run/'store-tests')],check=True)
subprocess.run([str(run/'store-tests')],env={**os.environ,'DYLD_LIBRARY_PATH':'/Library/Developer/CommandLineTools/Library/Developer/usr/lib'},check=True)
