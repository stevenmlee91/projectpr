#!/usr/bin/env python3
"""
Adds MileZeroWidgets extension target to the Xcode project.
Run from the project root: python3 add_widget_target.py
"""

import re, shutil, sys

PBXPROJ = "MarathonPlanner.xcodeproj/project.pbxproj"

# ── UUIDs ──────────────────────────────────────────────────────────────────────
# Widget target structure
WGT_TARGET          = "A1B2C3445566778899AA0001"
WGT_CFG_LIST        = "A1B2C3445566778899AA0002"
WGT_DEBUG_CFG       = "A1B2C3445566778899AA0003"
WGT_RELEASE_CFG     = "A1B2C3445566778899AA0004"
WGT_SOURCES         = "A1B2C3445566778899AA0005"
WGT_RESOURCES       = "A1B2C3445566778899AA0006"
WGT_FRAMEWORKS      = "A1B2C3445566778899AA0007"
WGT_APPEX_REF       = "A1B2C3445566778899AA0008"
WGT_GROUP           = "A1B2C3445566778899AA0009"
EMBED_PHASE         = "A1B2C3445566778899AA000A"
TARGET_DEP          = "A1B2C3445566778899AA000B"
CONTAINER_PROXY     = "A1B2C3445566778899AA000C"
EMBED_BF            = "A1B2C3445566778899AA000D"

# Shared file refs (new files in MarathonPlanner/)
FR_COLOR_HEX        = "A1B2C3445566778899AA000E"
FR_SNAPSHOT         = "A1B2C3445566778899AA0010"
FR_BUILDER          = "A1B2C3445566778899AA0011"
FR_PLAN_WIDGET      = "A1B2C3445566778899AA0012"
FR_APP_ENTITLEMENTS = "A1B2C3445566778899AA0018"

# Widget-only file refs (new files in MileZeroWidgets/)
FR_TIMELINE         = "A1B2C3445566778899AA0013"
FR_TODAY_SMALL      = "A1B2C3445566778899AA0014"
FR_TODAY_MED        = "A1B2C3445566778899AA0015"
FR_LOCK             = "A1B2C3445566778899AA0016"
FR_BUNDLE           = "A1B2C3445566778899AA0017"
FR_WGT_ENTITLEMENTS = "A1B2C3445566778899AA0019"
FR_WGT_INFOPLIST    = "A1B2C3445566778899AA001A"

# Existing TrainingPhase.swift ref (already in project)
FR_TRAINING_PHASE   = "B08F5A432FB0492D00BFFC53"

# Build files for main app Sources
BF_COLOR_HEX_APP    = "A1B2C3445566778899AA0020"
BF_SNAPSHOT_APP     = "A1B2C3445566778899AA0021"
BF_BUILDER_APP      = "A1B2C3445566778899AA0022"
BF_PLAN_WIDGET_APP  = "A1B2C3445566778899AA0023"

# Build files for widget Sources
BF_COLOR_HEX_WGT    = "A1B2C3445566778899AA0024"
BF_SNAPSHOT_WGT     = "A1B2C3445566778899AA0025"
BF_TRAINING_WGT     = "A1B2C3445566778899AA0026"
BF_TIMELINE_WGT     = "A1B2C3445566778899AA0027"
BF_TODAY_SMALL_WGT  = "A1B2C3445566778899AA0028"
BF_TODAY_MED_WGT    = "A1B2C3445566778899AA0029"
BF_LOCK_WGT         = "A1B2C3445566778899AA002A"
BF_BUNDLE_WGT       = "A1B2C3445566778899AA002B"

# WidgetKit framework
FR_WIDGETKIT        = "A1B2C3445566778899AA002C"
BF_WIDGETKIT_APP    = "A1B2C3445566778899AA002D"
BF_WIDGETKIT_WGT    = "A1B2C3445566778899AA002E"

# ── Read ───────────────────────────────────────────────────────────────────────
with open(PBXPROJ, encoding="utf-8") as f:
    c = f.read()

shutil.copy(PBXPROJ, PBXPROJ + ".backup_pre_widget")
print("Backup written to", PBXPROJ + ".backup_pre_widget")

# ── Guard against double-run ───────────────────────────────────────────────────
if WGT_TARGET in c:
    print("Widget target already present — exiting without changes.")
    sys.exit(0)

# ── 1. PBXBuildFile entries ───────────────────────────────────────────────────
new_build_files = f"""\
\t\t{EMBED_BF} /* MileZeroWidgets.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {WGT_APPEX_REF} /* MileZeroWidgets.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
\t\t{BF_COLOR_HEX_APP} /* Color+Hex.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_COLOR_HEX} /* Color+Hex.swift */; }};
\t\t{BF_SNAPSHOT_APP} /* WidgetPlanSnapshot.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_SNAPSHOT} /* WidgetPlanSnapshot.swift */; }};
\t\t{BF_BUILDER_APP} /* WidgetSnapshotBuilder.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_BUILDER} /* WidgetSnapshotBuilder.swift */; }};
\t\t{BF_PLAN_WIDGET_APP} /* PlanStore+Widget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_PLAN_WIDGET} /* PlanStore+Widget.swift */; }};
\t\t{BF_WIDGETKIT_APP} /* WidgetKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {FR_WIDGETKIT} /* WidgetKit.framework */; }};
\t\t{BF_COLOR_HEX_WGT} /* Color+Hex.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_COLOR_HEX} /* Color+Hex.swift */; }};
\t\t{BF_SNAPSHOT_WGT} /* WidgetPlanSnapshot.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_SNAPSHOT} /* WidgetPlanSnapshot.swift */; }};
\t\t{BF_TRAINING_WGT} /* TrainingPhase.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_TRAINING_PHASE} /* TrainingPhase.swift */; }};
\t\t{BF_TIMELINE_WGT} /* WidgetTimelineProvider.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_TIMELINE} /* WidgetTimelineProvider.swift */; }};
\t\t{BF_TODAY_SMALL_WGT} /* TodaySmallWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_TODAY_SMALL} /* TodaySmallWidget.swift */; }};
\t\t{BF_TODAY_MED_WGT} /* TodayMediumWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_TODAY_MED} /* TodayMediumWidget.swift */; }};
\t\t{BF_LOCK_WGT} /* LockScreenWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_LOCK} /* LockScreenWidget.swift */; }};
\t\t{BF_BUNDLE_WGT} /* MileZeroWidgetBundle.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {FR_BUNDLE} /* MileZeroWidgetBundle.swift */; }};
\t\t{BF_WIDGETKIT_WGT} /* WidgetKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {FR_WIDGETKIT} /* WidgetKit.framework */; }};
"""
c = c.replace("/* End PBXBuildFile section */",
              new_build_files + "/* End PBXBuildFile section */")

# ── 2. PBXCopyFilesBuildPhase (new section — embed widget in main app) ────────
copy_files_section = f"""
/* Begin PBXCopyFilesBuildPhase section */
\t\t{EMBED_PHASE} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{EMBED_BF} /* MileZeroWidgets.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

"""
c = c.replace("/* Begin PBXFileReference section */",
              copy_files_section + "/* Begin PBXFileReference section */")

# ── 3. PBXFileReference entries ───────────────────────────────────────────────
new_file_refs = f"""\
\t\t{WGT_APPEX_REF} /* MileZeroWidgets.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = MileZeroWidgets.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{FR_COLOR_HEX} /* Color+Hex.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "Color+Hex.swift"; sourceTree = "<group>"; }};
\t\t{FR_SNAPSHOT} /* WidgetPlanSnapshot.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetPlanSnapshot.swift; sourceTree = "<group>"; }};
\t\t{FR_BUILDER} /* WidgetSnapshotBuilder.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetSnapshotBuilder.swift; sourceTree = "<group>"; }};
\t\t{FR_PLAN_WIDGET} /* PlanStore+Widget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "PlanStore+Widget.swift"; sourceTree = "<group>"; }};
\t\t{FR_APP_ENTITLEMENTS} /* MarathonPlanner.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = MarathonPlanner.entitlements; sourceTree = "<group>"; }};
\t\t{FR_TIMELINE} /* WidgetTimelineProvider.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WidgetTimelineProvider.swift; sourceTree = "<group>"; }};
\t\t{FR_TODAY_SMALL} /* TodaySmallWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TodaySmallWidget.swift; sourceTree = "<group>"; }};
\t\t{FR_TODAY_MED} /* TodayMediumWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TodayMediumWidget.swift; sourceTree = "<group>"; }};
\t\t{FR_LOCK} /* LockScreenWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LockScreenWidget.swift; sourceTree = "<group>"; }};
\t\t{FR_BUNDLE} /* MileZeroWidgetBundle.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MileZeroWidgetBundle.swift; sourceTree = "<group>"; }};
\t\t{FR_WGT_ENTITLEMENTS} /* MileZeroWidgets.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = MileZeroWidgets.entitlements; sourceTree = "<group>"; }};
\t\t{FR_WGT_INFOPLIST} /* MileZeroWidgets/Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
\t\t{FR_WIDGETKIT} /* WidgetKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; }};
"""
c = c.replace("/* End PBXFileReference section */",
              new_file_refs + "/* End PBXFileReference section */")

# ── 4. PBXFrameworksBuildPhase — add WidgetKit to main app ───────────────────
# Main app frameworks phase is B0A62D762F9861A70093719D (currently empty files)
c = c.replace(
    "B0A62D762F9861A70093719D /* Frameworks */ = {\n"
    "\t\t\tisa = PBXFrameworksBuildPhase;\n"
    "\t\t\tbuildActionMask = 2147483647;\n"
    "\t\t\tfiles = (\n"
    "\t\t\t);\n"
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    "\t\t};",
    f"B0A62D762F9861A70093719D /* Frameworks */ = {{\n"
    f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
    f"\t\t\tbuildActionMask = 2147483647;\n"
    f"\t\t\tfiles = (\n"
    f"\t\t\t\t{BF_WIDGETKIT_APP} /* WidgetKit.framework in Frameworks */,\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};"
)

# Add widget's frameworks phase before End section
new_frameworks_phase = f"""\
\t\t{WGT_FRAMEWORKS} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{BF_WIDGETKIT_WGT} /* WidgetKit.framework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
c = c.replace("/* End PBXFrameworksBuildPhase section */",
              new_frameworks_phase + "/* End PBXFrameworksBuildPhase section */")

# ── 5. PBXGroup — root group: add widget group to children ───────────────────
# Root group children: B0A62D702F9861A70093719D
# Add widget group before Products
c = c.replace(
    "\t\t\t\tB0A62D7A2F9861A70093719D /* Products */,\n"
    "\t\t\t);\n"
    "\t\t\tsourceTree = \"<group>\";\n"
    "\t\t};\n"
    "\t\tB0A62D7A2F9861A70093719D /* Products */",
    f"\t\t\t\t{WGT_GROUP} /* MileZeroWidgets */,\n"
    f"\t\t\t\tB0A62D7A2F9861A70093719D /* Products */,\n"
    f"\t\t\t);\n"
    f"\t\t\tsourceTree = \"<group>\";\n"
    f"\t\t}};\n"
    f"\t\tB0A62D7A2F9861A70093719D /* Products */"
)

# Products group: add widget appex
c = c.replace(
    "\t\t\t\tB0A62D932F9861AB0093719D /* MarathonPlannerUITests.xctest */,\n"
    "\t\t\t);\n"
    "\t\t\tname = Products;",
    f"\t\t\t\tB0A62D932F9861AB0093719D /* MarathonPlannerUITests.xctest */,\n"
    f"\t\t\t\t{WGT_APPEX_REF} /* MileZeroWidgets.appex */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = Products;"
)

# Main app group: add new shared source files and entitlements
# Insert before Preview Content entry
c = c.replace(
    "\t\t\t\tB0A62D822F9861AB0093719D /* Preview Content */,\n"
    "\t\t\t);\n"
    "\t\t\tpath = MarathonPlanner;",
    f"\t\t\t\t{FR_COLOR_HEX} /* Color+Hex.swift */,\n"
    f"\t\t\t\t{FR_SNAPSHOT} /* WidgetPlanSnapshot.swift */,\n"
    f"\t\t\t\t{FR_BUILDER} /* WidgetSnapshotBuilder.swift */,\n"
    f"\t\t\t\t{FR_PLAN_WIDGET} /* PlanStore+Widget.swift */,\n"
    f"\t\t\t\t{FR_APP_ENTITLEMENTS} /* MarathonPlanner.entitlements */,\n"
    f"\t\t\t\tB0A62D822F9861AB0093719D /* Preview Content */,\n"
    f"\t\t\t);\n"
    f"\t\t\tpath = MarathonPlanner;"
)

# New widget group
new_widget_group = f"""\
\t\t{WGT_GROUP} /* MileZeroWidgets */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{FR_WGT_INFOPLIST} /* Info.plist */,
\t\t\t\t{FR_WGT_ENTITLEMENTS} /* MileZeroWidgets.entitlements */,
\t\t\t\t{FR_BUNDLE} /* MileZeroWidgetBundle.swift */,
\t\t\t\t{FR_TIMELINE} /* WidgetTimelineProvider.swift */,
\t\t\t\t{FR_TODAY_SMALL} /* TodaySmallWidget.swift */,
\t\t\t\t{FR_TODAY_MED} /* TodayMediumWidget.swift */,
\t\t\t\t{FR_LOCK} /* LockScreenWidget.swift */,
\t\t\t);
\t\t\tpath = MileZeroWidgets;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
c = c.replace("/* End PBXGroup section */",
              new_widget_group + "/* End PBXGroup section */")

# ── 6. Main app PBXNativeTarget — add embed phase + dependency ────────────────
c = c.replace(
    "\t\t\tbuildPhases = (\n"
    "\t\t\t\tB0A62D752F9861A70093719D /* Sources */,\n"
    "\t\t\t\tB0A62D762F9861A70093719D /* Frameworks */,\n"
    "\t\t\t\tB0A62D772F9861A70093719D /* Resources */,\n"
    "\t\t\t);\n"
    "\t\t\tbuildRules = (\n"
    "\t\t\t);\n"
    "\t\t\tdependencies = (\n"
    "\t\t\t);\n"
    "\t\t\tname = MarathonPlanner;",
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\tB0A62D752F9861A70093719D /* Sources */,\n"
    f"\t\t\t\tB0A62D762F9861A70093719D /* Frameworks */,\n"
    f"\t\t\t\tB0A62D772F9861A70093719D /* Resources */,\n"
    f"\t\t\t\t{EMBED_PHASE} /* Embed Foundation Extensions */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = (\n"
    f"\t\t\t);\n"
    f"\t\t\tdependencies = (\n"
    f"\t\t\t\t{TARGET_DEP} /* PBXTargetDependency */,\n"
    f"\t\t\t);\n"
    f"\t\t\tname = MarathonPlanner;"
)

# Widget extension PBXNativeTarget
new_native_target = f"""\
\t\t{WGT_TARGET} /* MileZeroWidgets */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {WGT_CFG_LIST} /* Build configuration list for PBXNativeTarget "MileZeroWidgets" */;
\t\t\tbuildPhases = (
\t\t\t\t{WGT_SOURCES} /* Sources */,
\t\t\t\t{WGT_FRAMEWORKS} /* Frameworks */,
\t\t\t\t{WGT_RESOURCES} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = MileZeroWidgets;
\t\t\tproductName = MileZeroWidgets;
\t\t\tproductReference = {WGT_APPEX_REF} /* MileZeroWidgets.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
"""
c = c.replace("/* End PBXNativeTarget section */",
              new_native_target + "/* End PBXNativeTarget section */")

# ── 7. PBXProject — targets list + TargetAttributes ──────────────────────────
c = c.replace(
    "\t\t\t\tB0A62D922F9861AB0093719D /* MarathonPlannerUITests */,\n"
    "\t\t\t);\n"
    "\t\t};\n"
    "/* End PBXProject section */",
    f"\t\t\t\tB0A62D922F9861AB0093719D /* MarathonPlannerUITests */,\n"
    f"\t\t\t\t{WGT_TARGET} /* MileZeroWidgets */,\n"
    f"\t\t\t);\n"
    f"\t\t}};\n"
    f"/* End PBXProject section */"
)

# TargetAttributes — add widget entry before closing brace
c = c.replace(
    "\t\t\t\t\tB0A62D922F9861AB0093719D = {\n"
    "\t\t\t\t\t\tCreatedOnToolsVersion = 14.3.1;\n"
    "\t\t\t\t\t\tTestTargetID = B0A62D782F9861A70093719D;\n"
    "\t\t\t\t\t};\n"
    "\t\t\t\t};\n"
    "\t\t\t};\n"
    "\t\t\tbuildConfigurationList = B0A62D742F9861A70093719D",
    f"\t\t\t\t\tB0A62D922F9861AB0093719D = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 14.3.1;\n"
    f"\t\t\t\t\t\tTestTargetID = B0A62D782F9861A70093719D;\n"
    f"\t\t\t\t\t}};\n"
    f"\t\t\t\t\t{WGT_TARGET} = {{\n"
    f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.2;\n"
    f"\t\t\t\t\t}};\n"
    f"\t\t\t\t}};\n"
    f"\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = B0A62D742F9861A70093719D"
)

# ── 8. PBXResourcesBuildPhase — add widget resources phase ───────────────────
new_resources_phase = f"""\
\t\t{WGT_RESOURCES} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
c = c.replace("/* End PBXResourcesBuildPhase section */",
              new_resources_phase + "/* End PBXResourcesBuildPhase section */")

# ── 9. PBXSourcesBuildPhase — add new files to main app, add widget phase ────
# Add new main app source files (after SavedRouteSheet.swift in Sources)
c = c.replace(
    "\t\t\t\tB08F59DB2FA5BBC400BFFC53 /* SavedRouteSheet.swift in Sources */,\n"
    "\t\t\t);\n"
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    "\t\t};\n"
    "\t\tB0A62D852F9861AB0093719D /* Sources */",
    f"\t\t\t\tB08F59DB2FA5BBC400BFFC53 /* SavedRouteSheet.swift in Sources */,\n"
    f"\t\t\t\t{BF_COLOR_HEX_APP} /* Color+Hex.swift in Sources */,\n"
    f"\t\t\t\t{BF_SNAPSHOT_APP} /* WidgetPlanSnapshot.swift in Sources */,\n"
    f"\t\t\t\t{BF_BUILDER_APP} /* WidgetSnapshotBuilder.swift in Sources */,\n"
    f"\t\t\t\t{BF_PLAN_WIDGET_APP} /* PlanStore+Widget.swift in Sources */,\n"
    f"\t\t\t);\n"
    f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
    f"\t\t}};\n"
    f"\t\tB0A62D852F9861AB0093719D /* Sources */"
)

# Add widget sources phase
new_sources_phase = f"""\
\t\t{WGT_SOURCES} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{BF_COLOR_HEX_WGT} /* Color+Hex.swift in Sources */,
\t\t\t\t{BF_SNAPSHOT_WGT} /* WidgetPlanSnapshot.swift in Sources */,
\t\t\t\t{BF_TRAINING_WGT} /* TrainingPhase.swift in Sources */,
\t\t\t\t{BF_TIMELINE_WGT} /* WidgetTimelineProvider.swift in Sources */,
\t\t\t\t{BF_TODAY_SMALL_WGT} /* TodaySmallWidget.swift in Sources */,
\t\t\t\t{BF_TODAY_MED_WGT} /* TodayMediumWidget.swift in Sources */,
\t\t\t\t{BF_LOCK_WGT} /* LockScreenWidget.swift in Sources */,
\t\t\t\t{BF_BUNDLE_WGT} /* MileZeroWidgetBundle.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
"""
c = c.replace("/* End PBXSourcesBuildPhase section */",
              new_sources_phase + "/* End PBXSourcesBuildPhase section */")

# ── 10. PBXTargetDependency + PBXContainerItemProxy ──────────────────────────
new_target_dep = f"""\
\t\t{TARGET_DEP} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {WGT_TARGET} /* MileZeroWidgets */;
\t\t\ttargetProxy = {CONTAINER_PROXY} /* PBXContainerItemProxy */;
\t\t}};
"""
c = c.replace("/* End PBXTargetDependency section */",
              new_target_dep + "/* End PBXTargetDependency section */")

new_container_proxy = f"""\
\t\t{CONTAINER_PROXY} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = B0A62D712F9861A70093719D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {WGT_TARGET};
\t\t\tremoteInfo = MileZeroWidgets;
\t\t}};
"""
c = c.replace("/* End PBXContainerItemProxy section */",
              new_container_proxy + "/* End PBXContainerItemProxy section */")

# ── 11. XCBuildConfiguration — widget Debug + Release ────────────────────────
# Also add CODE_SIGN_ENTITLEMENTS to main app configs
c = c.replace(
    "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
    "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
    "\t\t\t\tDEVELOPMENT_ASSET_PATHS = \"\\\"MarathonPlanner/Preview Content\\\"\";\n"
    "\t\t\t\tDEVELOPMENT_TEAM = BX2P9YS3TZ;\n"
    "\t\t\t\tENABLE_PREVIEWS = YES;\n"
    "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n"
    "\t\t\t\tINFOPLIST_FILE = MarathonPlanner/Info.plist;\n"
    "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Mile Zero\";",
    "\t\t\t\tCODE_SIGN_ENTITLEMENTS = MarathonPlanner/MarathonPlanner.entitlements;\n"
    "\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
    "\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n"
    "\t\t\t\tDEVELOPMENT_ASSET_PATHS = \"\\\"MarathonPlanner/Preview Content\\\"\";\n"
    "\t\t\t\tDEVELOPMENT_TEAM = BX2P9YS3TZ;\n"
    "\t\t\t\tENABLE_PREVIEWS = YES;\n"
    "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n"
    "\t\t\t\tINFOPLIST_FILE = MarathonPlanner/Info.plist;\n"
    "\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = \"Mile Zero\";"
)

new_build_configs = f"""\
\t\t{WGT_DEBUG_CFG} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MileZeroWidgets/MileZeroWidgets.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = BX2P9YS3TZ;
\t\t\t\tINFOPLIST_FILE = MileZeroWidgets/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = MarathonPlanner.MileZeroWidgets;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{WGT_RELEASE_CFG} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = MileZeroWidgets/MileZeroWidgets.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = BX2P9YS3TZ;
\t\t\t\tINFOPLIST_FILE = MileZeroWidgets/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.2;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = MarathonPlanner.MileZeroWidgets;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
c = c.replace("/* End XCBuildConfiguration section */",
              new_build_configs + "/* End XCBuildConfiguration section */")

# ── 12. XCConfigurationList — widget config list ──────────────────────────────
new_config_list = f"""\
\t\t{WGT_CFG_LIST} /* Build configuration list for PBXNativeTarget "MileZeroWidgets" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{WGT_DEBUG_CFG} /* Debug */,
\t\t\t\t{WGT_RELEASE_CFG} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""
c = c.replace("/* End XCConfigurationList section */",
              new_config_list + "/* End XCConfigurationList section */")

# ── Write ──────────────────────────────────────────────────────────────────────
with open(PBXPROJ, "w", encoding="utf-8") as f:
    f.write(c)

print("✓ project.pbxproj updated successfully.")
print("  Backup: " + PBXPROJ + ".backup_pre_widget")
print()
print("Next steps in Xcode:")
print("  1. Close and reopen Xcode (or the project)")
print("  2. Select the MarathonPlanner target → Signing & Capabilities")
print("     → '+ Capability' → App Groups → add 'group.MarathonPlanner.milezero'")
print("  3. Select the MileZeroWidgets target → Signing & Capabilities")
print("     → '+ Capability' → App Groups → add 'group.MarathonPlanner.milezero'")
print("  4. Build (Cmd+B) — both targets should compile clean.")
