#!/bin/bash

# 创建 Xcode 项目脚本
# 使用方法: chmod +x create_xcode_project.sh && ./create_xcode_project.sh

cd "$(dirname "$0")"

echo "正在创建 Xcode 项目..."

# 创建项目文件
mkdir -p GitRepoManager.xcodeproj

cat > GitRepoManager.xcodeproj/project.pbxproj << 'PBXPROJ'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		001 /* GitRepoManagerApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = 101; };
		002 /* MainView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 102; };
		003 /* Project.swift in Sources */ = {isa = PBXBuildFile; fileRef = 103; };
		004 /* GitRepository.swift in Sources */ = {isa = PBXBuildFile; fileRef = 104; };
		005 /* GitStatus.swift in Sources */ = {isa = PBXBuildFile; fileRef = 105; };
		006 /* GitFile.swift in Sources */ = {isa = PBXBuildFile; fileRef = 106; };
		007 /* GitBranch.swift in Sources */ = {isa = PBXBuildFile; fileRef = 107; };
		008 /* GitCommandRunner.swift in Sources */ = {isa = PBXBuildFile; fileRef = 108; };
		009 /* GitService.swift in Sources */ = {isa = PBXBuildFile; fileRef = 109; };
		010 /* ProjectScanner.swift in Sources */ = {isa = PBXBuildFile; fileRef = 110; };
		011 /* PersistenceService.swift in Sources */ = {isa = PBXBuildFile; fileRef = 111; };
		012 /* MainViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = 112; };
		013 /* RepositoryViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = 113; };
		014 /* TerminalViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = 114; };
		015 /* SidebarView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 115; };
		016 /* ProjectRowView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 116; };
		017 /* RepositoryRowView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 117; };
		018 /* RepositoryDetailView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 118; };
		019 /* ChangesTabView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 119; };
		020 /* FileListView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 120; };
		021 /* DiffPreviewView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 121; };
		022 /* BranchesTabView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 122; };
		023 /* TerminalView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 123; };
		024 /* StatusBadge.swift in Sources */ = {isa = PBXBuildFile; fileRef = 124; };
		025 /* AddProjectSheet.swift in Sources */ = {isa = PBXBuildFile; fileRef = 125; };
		026 /* AppLocalization.swift in Sources */ = {isa = PBXBuildFile; fileRef = 126; };
		027 /* GitCommit.swift in Sources */ = {isa = PBXBuildFile; fileRef = 127; };
		028 /* CommitRowView.swift in Sources */ = {isa = PBXBuildFile; fileRef = 128; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		100 /* GitRepoManager.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = GitRepoManager.app; sourceTree = BUILT_PRODUCTS_DIR; };
		101 /* GitRepoManagerApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitRepoManagerApp.swift; sourceTree = "<group>"; };
		102 /* MainView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MainView.swift; sourceTree = "<group>"; };
		103 /* Project.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Project.swift; sourceTree = "<group>"; };
		104 /* GitRepository.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitRepository.swift; sourceTree = "<group>"; };
		105 /* GitStatus.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitStatus.swift; sourceTree = "<group>"; };
		106 /* GitFile.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitFile.swift; sourceTree = "<group>"; };
		107 /* GitBranch.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitBranch.swift; sourceTree = "<group>"; };
		108 /* GitCommandRunner.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitCommandRunner.swift; sourceTree = "<group>"; };
		109 /* GitService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitService.swift; sourceTree = "<group>"; };
		110 /* ProjectScanner.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProjectScanner.swift; sourceTree = "<group>"; };
		111 /* PersistenceService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PersistenceService.swift; sourceTree = "<group>"; };
		112 /* MainViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MainViewModel.swift; sourceTree = "<group>"; };
		113 /* RepositoryViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RepositoryViewModel.swift; sourceTree = "<group>"; };
		114 /* TerminalViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TerminalViewModel.swift; sourceTree = "<group>"; };
		115 /* SidebarView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SidebarView.swift; sourceTree = "<group>"; };
		116 /* ProjectRowView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProjectRowView.swift; sourceTree = "<group>"; };
		117 /* RepositoryRowView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RepositoryRowView.swift; sourceTree = "<group>"; };
		118 /* RepositoryDetailView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RepositoryDetailView.swift; sourceTree = "<group>"; };
		119 /* ChangesTabView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ChangesTabView.swift; sourceTree = "<group>"; };
		120 /* FileListView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FileListView.swift; sourceTree = "<group>"; };
		121 /* DiffPreviewView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DiffPreviewView.swift; sourceTree = "<group>"; };
		122 /* BranchesTabView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BranchesTabView.swift; sourceTree = "<group>"; };
		123 /* TerminalView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TerminalView.swift; sourceTree = "<group>"; };
		124 /* StatusBadge.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StatusBadge.swift; sourceTree = "<group>"; };
		125 /* AddProjectSheet.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AddProjectSheet.swift; sourceTree = "<group>"; };
		126 /* AppLocalization.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppLocalization.swift; sourceTree = "<group>"; };
		127 /* GitCommit.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GitCommit.swift; sourceTree = "<group>"; };
		128 /* CommitRowView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CommitRowView.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXGroup section */
		200 = {
			isa = PBXGroup;
			children = (
				201 /* GitRepoManager */,
				202 /* Products */,
			);
			sourceTree = "<group>";
		};
		201 /* GitRepoManager */ = {
			isa = PBXGroup;
			children = (
				210 /* App */,
				211 /* Models */,
				212 /* Services */,
				213 /* ViewModels */,
				214 /* Views */,
			);
			path = GitRepoManager;
			sourceTree = "<group>";
		};
		202 /* Products */ = {
			isa = PBXGroup;
			children = (
				100 /* GitRepoManager.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		210 /* App */ = {
			isa = PBXGroup;
			children = (
				101 /* GitRepoManagerApp.swift */,
			);
			path = App;
			sourceTree = "<group>";
		};
		211 /* Models */ = {
			isa = PBXGroup;
			children = (
				103 /* Project.swift */,
				104 /* GitRepository.swift */,
				105 /* GitStatus.swift */,
				106 /* GitFile.swift */,
				107 /* GitBranch.swift */,
				127 /* GitCommit.swift */,
			);
			path = Models;
			sourceTree = "<group>";
		};
		212 /* Services */ = {
			isa = PBXGroup;
			children = (
				108 /* GitCommandRunner.swift */,
				109 /* GitService.swift */,
				110 /* ProjectScanner.swift */,
				111 /* PersistenceService.swift */,
				126 /* AppLocalization.swift */,
			);
			path = Services;
			sourceTree = "<group>";
		};
		213 /* ViewModels */ = {
			isa = PBXGroup;
			children = (
				112 /* MainViewModel.swift */,
				113 /* RepositoryViewModel.swift */,
				114 /* TerminalViewModel.swift */,
			);
			path = ViewModels;
			sourceTree = "<group>";
		};
		214 /* Views */ = {
			isa = PBXGroup;
			children = (
				102 /* MainView.swift */,
				215 /* Sidebar */,
				216 /* Detail */,
				217 /* Terminal */,
				218 /* Components */,
			);
			path = Views;
			sourceTree = "<group>";
		};
		215 /* Sidebar */ = {
			isa = PBXGroup;
			children = (
				115 /* SidebarView.swift */,
				116 /* ProjectRowView.swift */,
				117 /* RepositoryRowView.swift */,
			);
			path = Sidebar;
			sourceTree = "<group>";
		};
		216 /* Detail */ = {
			isa = PBXGroup;
			children = (
				118 /* RepositoryDetailView.swift */,
				119 /* ChangesTabView.swift */,
				120 /* FileListView.swift */,
				121 /* DiffPreviewView.swift */,
				122 /* BranchesTabView.swift */,
				128 /* CommitRowView.swift */,
			);
			path = Detail;
			sourceTree = "<group>";
		};
		217 /* Terminal */ = {
			isa = PBXGroup;
			children = (
				123 /* TerminalView.swift */,
			);
			path = Terminal;
			sourceTree = "<group>";
		};
		218 /* Components */ = {
			isa = PBXGroup;
			children = (
				124 /* StatusBadge.swift */,
				125 /* AddProjectSheet.swift */,
			);
			path = Components;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		300 /* GitRepoManager */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 400;
			buildPhases = (
				301 /* Sources */,
				302 /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = GitRepoManager;
			productName = GitRepoManager;
			productReference = 100 /* GitRepoManager.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		500 /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = 501;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				"zh-Hans",
			);
			mainGroup = 200;
			productRefGroup = 202 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				300 /* GitRepoManager */,
			);
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		301 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				001 /* GitRepoManagerApp.swift in Sources */,
				002 /* MainView.swift in Sources */,
				003 /* Project.swift in Sources */,
				004 /* GitRepository.swift in Sources */,
				005 /* GitStatus.swift in Sources */,
				006 /* GitFile.swift in Sources */,
				007 /* GitBranch.swift in Sources */,
				008 /* GitCommandRunner.swift in Sources */,
				009 /* GitService.swift in Sources */,
				010 /* ProjectScanner.swift in Sources */,
				011 /* PersistenceService.swift in Sources */,
				012 /* MainViewModel.swift in Sources */,
				013 /* RepositoryViewModel.swift in Sources */,
				014 /* TerminalViewModel.swift in Sources */,
				015 /* SidebarView.swift in Sources */,
				016 /* ProjectRowView.swift in Sources */,
				017 /* RepositoryRowView.swift in Sources */,
				018 /* RepositoryDetailView.swift in Sources */,
				019 /* ChangesTabView.swift in Sources */,
				020 /* FileListView.swift in Sources */,
				021 /* DiffPreviewView.swift in Sources */,
				022 /* BranchesTabView.swift in Sources */,
				023 /* TerminalView.swift in Sources */,
				024 /* StatusBadge.swift in Sources */,
				025 /* AddProjectSheet.swift in Sources */,
				026 /* AppLocalization.swift in Sources */,
				027 /* GitCommit.swift in Sources */,
				028 /* CommitRowView.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXFrameworksBuildPhase section */
		302 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin XCBuildConfiguration section */
		600 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CODE_SIGN_STYLE = Automatic;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		601 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CODE_SIGN_STYLE = Automatic;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			};
			name = Release;
		};
		602 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.developer-tools";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.GitRepoManager;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		603 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = "";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_HARDENED_RUNTIME = YES;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.developer-tools";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.example.GitRepoManager;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		400 /* Build configuration list for PBXNativeTarget "GitRepoManager" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				602 /* Debug */,
				603 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		501 /* Build configuration list for PBXProject "GitRepoManager" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				600 /* Debug */,
				601 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

	};
	rootObject = 500 /* Project object */;
}
PBXPROJ

echo "项目文件已创建！"
echo ""
echo "下一步："
echo "1. 双击 GitRepoManager.xcodeproj 在 Xcode 中打开"
echo "2. 选择你的开发者团队 (Signing & Capabilities)"
echo "3. 按 ⌘R 运行应用"
