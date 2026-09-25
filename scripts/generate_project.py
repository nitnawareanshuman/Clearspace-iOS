#!/usr/bin/env python3
"""Recreate the checked-in Xcode project with Python's standard library only."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def obj(key, isa, **values):
    ident = uid(key)
    objects[ident] = dict(isa=isa, **values)
    return ident

def configs(key, shared):
    refs = []
    for name in ('Debug', 'Release'):
        settings = dict(shared)
        settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if name == 'Debug' else '-O',
                        DEBUG_INFORMATION_FORMAT='dwarf' if name == 'Debug' else 'dwarf-with-dsym')
        if name == 'Debug': settings.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        refs.append(obj(key + name, 'XCBuildConfiguration', name=name, buildSettings=settings))
    return obj(key + 'configs', 'XCConfigurationList', buildConfigurations=refs,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

app_product = obj('app-product', 'PBXFileReference', explicitFileType='wrapper.application', path='Clearspace.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = obj('test-product', 'PBXFileReference', explicitFileType='wrapper.cfbundle', path='ClearspaceTests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
app_children, test_children, source_builds, test_builds, resources = [], [], [], [], []
for folder, children, builds in [('Clearspace', app_children, source_builds), ('ClearspaceTests', test_children, test_builds)]:
    for path in sorted((ROOT / folder).rglob('*.swift')):
        rel = str(path.relative_to(ROOT))
        ref = obj(rel, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=rel, sourceTree='SOURCE_ROOT')
        children.append(ref)
        builds.append(obj('build-' + rel, 'PBXBuildFile', fileRef=ref))
for rel, kind in [('Clearspace/Assets.xcassets', 'folder.assetcatalog'), ('Clearspace/PrivacyInfo.xcprivacy', 'text.xml')]:
    ref = obj(rel, 'PBXFileReference', lastKnownFileType=kind, path=rel, sourceTree='SOURCE_ROOT')
    app_children.append(ref)
    resources.append(obj('build-' + rel, 'PBXBuildFile', fileRef=ref))
app_children.append(obj('info', 'PBXFileReference', lastKnownFileType='text.plist.xml', path='Clearspace/Info.plist', sourceTree='SOURCE_ROOT'))
app_group = obj('app-group', 'PBXGroup', name='Clearspace', children=app_children, sourceTree='<group>')
tests_group = obj('tests-group', 'PBXGroup', name='ClearspaceTests', children=test_children, sourceTree='<group>')
products = obj('products', 'PBXGroup', name='Products', children=[app_product, test_product], sourceTree='<group>')
root_group = obj('root-group', 'PBXGroup', children=[app_group, tests_group, products], sourceTree='<group>')
def phase(key, isa, files): return obj(key, isa, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0)
app_phases = [phase('app-sources','PBXSourcesBuildPhase',source_builds), phase('app-frameworks','PBXFrameworksBuildPhase',[]), phase('app-resources','PBXResourcesBuildPhase',resources)]
test_phases = [phase('test-sources','PBXSourcesBuildPhase',test_builds), phase('test-frameworks','PBXFrameworksBuildPhase',[]), phase('test-resources','PBXResourcesBuildPhase',[])]
common = dict(SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos',
              TARGETED_DEVICE_FAMILY='1', CODE_SIGN_STYLE='Automatic', CURRENT_PROJECT_VERSION='1',
              MARKETING_VERSION='0.1.0', SUPPORTED_PLATFORMS='iphoneos iphonesimulator',
              SUPPORTS_MACCATALYST='NO', SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD='NO',
              CLANG_ENABLE_MODULES='YES')
app_settings = dict(common, PRODUCT_BUNDLE_IDENTIFIER='com.anshumannitnaware.Clearspace', PRODUCT_NAME='$(TARGET_NAME)',
                    GENERATE_INFOPLIST_FILE='NO', INFOPLIST_FILE='Clearspace/Info.plist',
                    ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor',
                    LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks'])
app_target = obj('app-target', 'PBXNativeTarget', name='Clearspace', productName='Clearspace',
    buildConfigurationList=configs('app',app_settings), buildPhases=app_phases, buildRules=[], dependencies=[],
    productReference=app_product, productType='com.apple.product-type.application')
proxy = obj('test-proxy', 'PBXContainerItemProxy', containerPortal=uid('project'), proxyType=1,
            remoteGlobalIDString=app_target, remoteInfo='Clearspace')
dep = obj('test-dep', 'PBXTargetDependency', target=app_target, targetProxy=proxy)
test_settings = dict(common, PRODUCT_BUNDLE_IDENTIFIER='com.anshumannitnaware.ClearspaceTests', PRODUCT_NAME='$(TARGET_NAME)',
                     GENERATE_INFOPLIST_FILE='YES', TEST_HOST='$(BUILT_PRODUCTS_DIR)/Clearspace.app/Clearspace',
                     BUNDLE_LOADER='$(TEST_HOST)', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks'])
test_target = obj('test-target', 'PBXNativeTarget', name='ClearspaceTests', productName='ClearspaceTests',
    buildConfigurationList=configs('tests',test_settings), buildPhases=test_phases, buildRules=[], dependencies=[dep],
    productReference=test_product, productType='com.apple.product-type.bundle.unit-test')
project = obj('project','PBXProject', attributes={'LastUpgradeCheck':'1600','TargetAttributes':{app_target:{'CreatedOnToolsVersion':'16.0'},test_target:{'CreatedOnToolsVersion':'16.0','TestTargetID':app_target}}},
              buildConfigurationList=configs('project', {'CLANG_ENABLE_MODULES':'YES','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0'}),
              compatibilityVersion='Xcode 14.0', developmentRegion='en', hasScannedForEncodings=0,
              knownRegions=['en','Base'], mainGroup=root_group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app_target,test_target])
def serialize(value, depth=0):
    tab = '\t' * depth
    if isinstance(value, dict):
        return '{\n' + ''.join('\t'*(depth+1) + json.dumps(str(k)) + ' = ' + serialize(v,depth+1) + ';\n' for k,v in value.items()) + tab + '}'
    if isinstance(value,list): return '(\n'+''.join('\t'*(depth+1)+serialize(v,depth+1)+',\n' for v in value)+tab+')'
    return str(value) if isinstance(value,int) else json.dumps(value)
p = ROOT / 'Clearspace.xcodeproj'
p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize(dict(archiveVersion=1,classes={},objectVersion=56,objects=objects,rootObject=project))+'\n')
scheme = p/'xcshareddata/xcschemes'
scheme.mkdir(parents=True,exist_ok=True)
def reference(ident,name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:Clearspace.xcodeproj"/>'
(scheme/'Clearspace.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference(app_target,'Clearspace.app')}</BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference(test_target,'ClearspaceTests.xctest')}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference(app_target,'Clearspace.app')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference(app_target,'Clearspace.app')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated {p.name}: {len(source_builds)} app sources, {len(test_builds)} test source, {len(resources)} resources')
