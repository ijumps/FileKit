//
//  FileKitTests_iOS.swift
//  FileKitTests-iOS
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015-2016 Nikolai Vazquez
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//  swiftlint:disable type_body_length
//  swiftlint:disable file_length
//

import XCTest
import FileKit

class FileKitTests: XCTestCase {
    
    // MARK: - Path
    
    class Delegate: NSObject, NSFileManagerDelegate {
        var expectedSourcePath: Path = ""
        var expectedDestinationPath: Path = ""
        func fileManager(
            fileManager: NSFileManager,
            shouldCopyItemAtPath srcPath: String,
                                 toPath dstPath: String
            ) -> Bool {
            XCTAssertEqual(srcPath, expectedSourcePath.rawValue)
            XCTAssertEqual(dstPath, expectedDestinationPath.rawValue)
            return true
        }
    }
    
    func testPathFileManagerDelegate() {
        do {
            var sourcePath = .UserTemporary + "filekit_test_filemanager_delegate"
            let destinationPath = Path("\(sourcePath)1")
            try sourcePath.createFile()
            
            var delegate: Delegate {
                let delegate = Delegate()
                delegate.expectedSourcePath = sourcePath
                delegate.expectedDestinationPath = destinationPath
                return delegate
            }
            
            let d1 = delegate
            sourcePath.fileManagerDelegate = d1
            XCTAssertTrue(d1 === sourcePath.fileManagerDelegate)
            
            try sourcePath +>! destinationPath
            
            var secondSourcePath = sourcePath
            secondSourcePath.fileManagerDelegate = delegate
            XCTAssertFalse(sourcePath.fileManagerDelegate === secondSourcePath.fileManagerDelegate)
            try secondSourcePath +>! destinationPath
            
        } catch {
            XCTFail(String(error))
        }
        
    }
    
    func testFindingPaths() {
        let homeFolders = Path.UserHome.find(searchDepth: 0) { $0.isDirectory }
        XCTAssertFalse(homeFolders.isEmpty, "Home folder is not empty")
        
        let rootFiles = Path.Root.find(searchDepth: 1) { !$0.isDirectory }
        XCTAssertFalse(rootFiles.isEmpty)
    }
    
    func testPathStringLiteralConvertible() {
        let a  = "/Users" as Path
        let b: Path = "/Users"
        let c = Path("/Users")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, c)
        XCTAssertEqual(b, c)
    }
    
    func testPathStringInterpolationConvertible() {
        let path: Path = "\(Path.UserTemporary)/testfile_\(10)"
        XCTAssertEqual(path.rawValue, Path.UserTemporary.rawValue + "/testfile_10")
    }
    
    func testPathEquality() {
        let a: Path = "~"
        let b: Path = "~/"
        let c: Path = "~//"
        let d: Path = "~/./"
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, c)
        XCTAssertEqual(a, d)
    }
    
    func testStandardizingPath() {
        let a: Path = "~"
        let b: Path = .UserHome
        XCTAssertEqual(a.standardized, b.standardized)
    }
    
    func testPathIsDirectory() {
        let d = Path.SystemApplications
        XCTAssertTrue(d.isDirectory)
    }
    
    func testSequence() {
        var i = 0
        let parent = Path.UserTemporary
        for _ in parent {
            i += 1
        }
        print("\(i) files under \(parent)")
        
        i = 0
        for (_, _) in Path.UserTemporary.enumerate() {
            i += 1
        }
    }
    
    func testPathExtension() {
        var path = Path.UserTemporary + "file.txt"
        XCTAssertEqual(path.pathExtension, "txt")
        path.pathExtension = "pdf"
        XCTAssertEqual(path.pathExtension, "pdf")
    }
    
    func testPathParent() {
        let a: Path = "/"
        let b: Path = a + "Users"
        XCTAssertEqual(a, b.parent)
    }
    
    func testPathChildren() {
        let p: Path = .UserHome
        XCTAssertNotEqual(p.children(), [])
    }
    
    func testPathRecursiveChildren() {
        let p: Path = Path.UserTemporary
        let children = p.children(recursive: true)
        XCTAssertNotEqual(children, [])
    }
    
    func testRoot() {
        
        let root = Path.Root
        XCTAssertTrue(root.isRoot)
        
        XCTAssertEqual(root.standardized, root)
        XCTAssertEqual(root.parent, root)
        
        var p: Path = Path.UserTemporary
        XCTAssertFalse(p.isRoot)
        
        while !p.isRoot { p = p.parent }
        XCTAssertTrue(p.isRoot)
        
        let empty = Path("")
        XCTAssertFalse(empty.isRoot)
        XCTAssertEqual(empty.standardized, empty)
        
        XCTAssertTrue(Path("/.").isRoot)
        XCTAssertTrue(Path("//").isRoot)
    }
    
    func testFamily() {
        let p: Path = Path.UserTemporary + "Family"
        try! p.createDirectory()
        let pChilds = p + "FamilyParent/aFamilyChild"
        try! pChilds.createDirectory()
        let children = p.children()
        
        guard let child  = children.first else {
            XCTFail("No child into \(p)")
            return
        }
        XCTAssertTrue(child.isAncestorOfPath(p))
        XCTAssertTrue(p.isChildOfPath(child))
        
        XCTAssertFalse(p.isAncestorOfPath(child))
        XCTAssertFalse(p.isAncestorOfPath(p))
        XCTAssertFalse(p.isChildOfPath(p))
        
        let directories = children.filter { $0.isDirectory }
        
        guard let directory  = directories.first, childOfChild = directory.children().first else {
            XCTFail("No child of child into \(p)")
            return
        }
        XCTAssertTrue(childOfChild.isAncestorOfPath(p))
        XCTAssertFalse(p.isChildOfPath(childOfChild, recursive: false))
        XCTAssertTrue(p.isChildOfPath(childOfChild, recursive: true))
        
        
        // common ancestor
        XCTAssertTrue(p.commonAncestor(Path.Root).isRoot)
        XCTAssertEqual(.UserDownloads <^> .UserDocuments, Path.UserHome)
        XCTAssertEqual(("~/Downloads" <^> "~/Documents").rawValue, "~")
    }
    
    func testPathAttributes() {
        
        let a = .UserTemporary + "test.txt"
        let b = .UserTemporary + "TestDir"
        do {
            try "Hello there, sir" |> TextFile(path: a)
            try b.createDirectory()
        } catch {
            XCTFail(String(error))
        }
        
        for p in [a, b] {
            print(p.creationDate)
            print(p.modificationDate)
            print(p.ownerName)
            print(p.ownerID)
            print(p.groupName)
            print(p.groupID)
            print(p.extensionIsHidden)
            print(p.posixPermissions)
            print(p.fileReferenceCount)
            print(p.fileSize)
            print(p.filesystemFileNumber)
            print(p.fileType)
            print("")
        }
    }
    
    func testPathSubscript() {
        let path = "~/Library/Preferences" as Path
        
        let a = path[0]
        XCTAssertEqual(a, "~")
        
        let b = path[2]
        XCTAssertEqual(b, path)
    }
    
    func testAddingPaths() {
        let a: Path = "~/Desktop"
        let b: Path = "Files"
        XCTAssertEqual(a + b, "~/Desktop/Files")
    }
    
    func testPathPlusEquals() {
        var a: Path = "~/Desktop"
        a += "Files"
        XCTAssertEqual(a, "~/Desktop/Files")
    }
    
    
    func testPathSymlinking() {
        do {
            let testDir: Path = .UserTemporary + "filekit_test_symlinking"
            if testDir.exists && !testDir.isDirectory {
                try testDir.deleteFile()
                XCTAssertFalse(testDir.exists)
            }
            
            try testDir.createDirectory()
            XCTAssertTrue(testDir.exists)
            
            let testFile = TextFile(path: testDir + "test_file.txt")
            try "FileKit test" |> testFile
            XCTAssertTrue(testFile.exists)
            
            let symDir = testDir + "sym_dir"
            if symDir.exists && !symDir.isDirectory {
                try symDir.deleteFile()
            }
            try symDir.createDirectory()
            
            // "/temporary/symDir/test_file.txt"
            try testFile =>! symDir
            
            let symPath = symDir + testFile.name
            XCTAssertTrue(symPath.isSymbolicLink)
            
            let symPathContents = try String(contentsOfPath: symPath)
            XCTAssertEqual(symPathContents, "FileKit test")
            
            let symLink = testDir + "test_file_link.txt"
            try testFile =>! symLink
            XCTAssertTrue(symLink.isSymbolicLink)
            
            let symLinkContents = try String(contentsOfPath: symLink)
            XCTAssertEqual(symLinkContents, "FileKit test")
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testPathOperators() {
        let p: Path = "~"
        let ps = p.standardized
        XCTAssertEqual(ps, p%)
        XCTAssertEqual(ps.parent, ps^)
    }
    
    func testCurrent() {
        let oldCurrent: Path = .Current
        let newCurrent: Path = .UserTemporary
        
        XCTAssertNotEqual(oldCurrent, newCurrent) // else there is no test
        
        Path.Current = newCurrent
        XCTAssertEqual(Path.Current, newCurrent)
        
        Path.Current = oldCurrent
        XCTAssertEqual(Path.Current, oldCurrent)
    }
    
    func testChangeDirectory() {
        Path.UserTemporary.changeDirectory {
            XCTAssertEqual(Path.Current, Path.UserTemporary)
        }
        
        Path.UserDesktop </> {
            XCTAssertEqual(Path.Current, Path.UserDesktop)
        }
        
        XCTAssertNotEqual(Path.Current, Path.UserTemporary)
    }
    
    // no volumes on iOS
    func testVolumes() {
        var volumes = Path.volumes()
        XCTAssertFalse(volumes.isEmpty, "No volume")
        
        for volume in volumes {
            XCTAssertNotNil("\(volume)")
        }
        
        volumes = Path.volumes(.SkipHiddenVolumes)
        XCTAssertFalse(volumes.isEmpty, "No visible volume")
        
        for volume in volumes {
            XCTAssertNotNil("\(volume)")
        }
    }
    
    func testURL() {
        let path: Path = .UserTemporary
        let url = path.url
        if let pathFromURL = Path(url: url) {
            XCTAssertEqual(pathFromURL, path)
            
            let subPath = pathFromURL + "test"
            XCTAssertEqual(Path(url: url.URLByAppendingPathComponent("test")), subPath)
        } else {
            XCTFail("Not able to create Path from URL")
        }
    }
    
    func testBookmarkData() {
        let path: Path = .UserTemporary
        XCTAssertNotNil(path.bookmarkData)
        
        if let bookmarkData = path.bookmarkData {
            if let pathFromBookmarkData = Path(bookmarkData: bookmarkData) {
                XCTAssertEqual(pathFromBookmarkData, path)
            } else {
                XCTFail("Not able to create Path from Bookmark Data")
            }
        }
    }
    
    func testGroupIdentifier() {
        let path = Path(groupIdentifier: "com.nikolaivazquez.FileKitTests")
        XCTAssertNotNil(path, "Not able to create Path from group identifier")
    }
    
    func testTouch() {
        let path: Path = .UserTemporary + "filekit_test.touch"
        do {
            if path.exists { try path.deleteFile() }
            XCTAssertFalse(path.exists)
            
            try path.touch()
            XCTAssertTrue(path.exists)
            
            guard let modificationDate = path.modificationDate else {
                XCTFail("Failed to get modification date")
                return
            }
            
            sleep(1)
            
            try path.touch()
            
            guard let newModificationDate = path.modificationDate else {
                XCTFail("Failed to get modification date")
                return
            }
            
            XCTAssertTrue(modificationDate < newModificationDate)
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testCreateDirectory() {
        let dir: Path = .UserTemporary + "filekit_testdir"
        
        do {
            if dir.exists { try dir.deleteFile() }
        } catch {
            XCTFail(String(error))
        }
        
        defer {
            do {
                if dir.exists { try dir.deleteFile() }
            } catch {
                XCTFail(String(error))
            }
        }
        
        do {
            XCTAssertFalse(dir.exists)
            try dir.createDirectory()
            XCTAssertTrue(dir.exists)
        } catch {
            XCTFail(String(error))
        }
        do {
            XCTAssertTrue(dir.exists)
            try dir.createDirectory(withIntermediateDirectories: false)
            XCTFail("must throw exception")
        } catch FileKitError.CreateDirectoryFail {
            print("Create directory fail ok")
        } catch {
            XCTFail("Unknown error: " + String(error))
        }
        do {
            XCTAssertTrue(dir.exists)
            try dir.createDirectory(withIntermediateDirectories: true)
            XCTAssertTrue(dir.exists)
        } catch {
            XCTFail("Unexpected error: " + String(error))
        }
    }
    
    // not all path exists in iOS
    func testWellKnownDirectories() {
        var paths: [Path] = [
            .UserHome, .UserTemporary, .UserCaches, .UserDesktop, .UserDocuments,
            .UserAutosavedInformation, .UserDownloads, .UserLibrary, .UserMovies,
            .UserMusic, .UserPictures, .UserApplicationSupport, .UserApplications,
            .UserSharedPublic
        ]
        paths += [
            .SystemApplications, .SystemApplicationSupport, .SystemLibrary,
            .SystemCoreServices, .SystemPreferencePanes /* .SystemPrinterDescription,*/
        ]
        #if os(OSX)
            paths += [.UserTrash] // .UserApplicationScripts (not testable)
        #endif
        
        for path in paths {
            XCTAssertTrue(path.exists, path.rawValue)
        }
        
        // all
        
        XCTAssertTrue(Path.AllLibraries.contains(.UserLibrary))
        XCTAssertTrue(Path.AllLibraries.contains(.SystemLibrary))
        XCTAssertTrue(Path.AllApplications.contains(.UserApplications))
        XCTAssertTrue(Path.AllApplications.contains(.SystemApplications))
        
        // temporary
        XCTAssertFalse(Path.ProcessTemporary.exists)
        XCTAssertFalse(Path.UniqueTemporary.exists)
        XCTAssertNotEqual(Path.UniqueTemporary, Path.UniqueTemporary)
    }
    
    // MARK: - TextFile
    
    let textFile = TextFile(path: .UserTemporary + "filekit_test.txt")
    
    func testFileName() {
        XCTAssertEqual(TextFile(path: "/Users/").name, "Users")
    }
    
    func testTextFileExtension() {
        XCTAssertEqual(textFile.pathExtension, "txt")
    }
    
    func testTextFileExists() {
        do {
            try textFile.create()
            XCTAssertTrue(textFile.exists)
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testWriteToTextFile() {
        do {
            try textFile.write("This is some test.")
            try textFile.write("This is another test.", atomically: false)
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testTextFileOperators() {
        do {
            let text = "FileKit Test"
            
            try text |> textFile
            var contents = try textFile.read()
            XCTAssertTrue(contents.hasSuffix(text))
            
            try text |>> textFile
            contents = try textFile.read()
            XCTAssertTrue(contents.hasSuffix(text + "\n" + text))
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testTextFileStreamReader() {
        do {
            let expectedLines = [
                "Lorem ipsum dolor sit amet",
                "consectetur adipiscing elit",
                "Sed non risus"
            ]
            let separator = "\n"
            try expectedLines.joinWithSeparator(separator) |> textFile
            
            if let reader = textFile.streamReader() {
                var lines = [String]()
                for line in reader {
                    lines.append(line)
                }
                XCTAssertEqual(expectedLines, lines)
                
            } else {
                XCTFail("Failed to create reader")
            }
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testTextFileGrep() {
        do {
            let expectedLines = [
                "Lorem ipsum dolor sit amet",
                "consectetur adipiscing elit",
                "Sed non risus"
            ]
            let separator = "\n"
            try expectedLines.joinWithSeparator(separator) |> textFile
            
            // all
            var result = textFile | "e"
            XCTAssertEqual(result, expectedLines)
            
            // not all
            result = textFile |- "e"
            XCTAssertTrue(result.isEmpty)
            
            // specific line
            result = textFile | "eli"
            XCTAssertEqual(result, [expectedLines[1]])
            
            // the other line
            result = textFile |- "eli"
            XCTAssertEqual(result, [expectedLines[0], expectedLines[2]])
            
            // regex
            result = textFile |~ "e.*i.*e.*"
            XCTAssertEqual(result, [expectedLines[0], expectedLines[1]])
            
            // this not a regex
            result = textFile | "e.*i.*e.*"
            XCTAssertTrue(result.isEmpty)
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - FileType
    
    func testFileTypeComparable() {
        let textFile1 = TextFile(path: .UserTemporary + "filekit_test_comparable1.txt")
        let textFile2 = TextFile(path: .UserTemporary + "filekit_test_comparable2.txt")
        do {
            try "1234567890" |> textFile1
            try "12345"      |> textFile2
            XCTAssert(textFile1 > textFile2)
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - FilePermissions
    
    func testFilePermissions() {
        let swift: Path = "/usr/bin/swift"
        if swift.exists {
            XCTAssertTrue(swift.filePermissions.contains([.Read, .Execute]))
        }
        
        let file: Path = .UserTemporary + "filekit_test_filepermissions"
        
        do {
            try file.createFile()
            XCTAssertTrue(file.filePermissions.contains([.Read, .Write]))
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - DictionaryFile
    
    let dictionaryFile = DictionaryFile(path: .UserTemporary + "filekit_test_dictionary.plist")
    
    func testWriteToDictionaryFile() {
        do {
            let dict = NSMutableDictionary()
            dict["FileKit"] = true
            dict["Hello"] = "World"
            
            try dictionaryFile.write(dict)
            let contents = try dictionaryFile.read()
            XCTAssertEqual(contents, dict)
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - ArrayFile
    
    let arrayFile = ArrayFile(path: .UserTemporary + "filekit_test_array.plist")
    
    func testWriteToArrayFile() {
        do {
            let array: NSArray = ["ABCD", "WXYZ"]
            
            try arrayFile.write(array)
            let contents = try arrayFile.read()
            XCTAssertEqual(contents, array)
            
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - DataFile
    
    let dataFile = DataFile(path: .UserTemporary + "filekit_test_data")
    
    func testWriteToDataFile() {
        do {
            let data = ("FileKit test" as NSString).dataUsingEncoding(NSUTF8StringEncoding)!
            try dataFile.write(data)
            let contents = try dataFile.read()
            XCTAssertEqual(contents, data)
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - String+FileKit
    
    let stringFile = File<String>(path: .UserTemporary + "filekit_stringtest.txt")
    
    func testStringInitializationFromPath() {
        do {
            let message = "Testing string init..."
            try stringFile.write(message)
            let contents = try String(contentsOfPath: stringFile.path)
            XCTAssertEqual(contents, message)
        } catch {
            XCTFail(String(error))
        }
    }
    
    func testStringWriting() {
        do {
            let message = "Testing string writing..."
            try message.writeToPath(stringFile.path)
            let contents = try String(contentsOfPath: stringFile.path)
            XCTAssertEqual(contents, message)
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - Image
    
    func testImageWriting() {
        let url = "https://raw.githubusercontent.com/nvzqz/FileKit/assets/logo.png"
        let img = Image.imageFromURLString(url) ?? Image()
        do {
            let path: Path = .UserTemporary + "filekit_imagetest.png"
            try img.writeToPath(path)
        } catch {
            XCTFail(String(error))
        }
    }
    
    // MARK: - Watch
    
    func testWatch() {
        let pathToWatch = .UserTemporary + "filekit_test_watch"
        try? pathToWatch.createFile()
        let expectation = "event"
        let operation = {
            do {
                let message = "Testing file system event when writing..."
                try message.writeToPath(pathToWatch, atomically: false)
            } catch {
                XCTFail(String(error))
            }
        }
        
        // Do watch test
        let expt = self.expectationWithDescription(expectation)
        let watcher = pathToWatch.watch { watch in
            print("\n\n\(watch.currentEvent)\n\n")
            // XXX here could check expected event type according to operation
            expt.fulfill()
            watch.close()
        }
        defer {
            //watcher.close()
        }
        sleep(1)
        operation()
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    /// Callbacks call asynchronous on a a system-defined global concurrent queue, the result may out of order
    ///
    /// Capture events may be split or merge. a single one like:
    /// `Optional(DispatchVnodeEvents[Attribute(8)])` and `Optional(DispatchVnodeEvents[Extend(4)])` 
    /// or a merge one like: `Optional(DispatchVnodeEvents[Extend(4), Attribute(8)])`
    ///
    /// This may cause `NSInternalInconsistencyException (API violation)` because two events happen and call `expt.fulfill()` twice.
    /// Call `watcher.close()` right after `expt.fulfill()` is likely to solve this.
    ///
    /// Also, Cancellation with `dispatch_source_cancel` prevents any further invocation of the event handler block for the specified dispatch source, but does not interrupt an event handler block that is already in progress.
    ///
    /// There is a latency between init the watch and the kernel readly to process the delegate.
    /// `dispatch_source_create` create the `source` asynchronous, before the kernel readly to monitor and process the delegate, following operation which affects the file may already happened.
    ///
    /// This cause `DispatchVnodeWatcher` may miss some events, like only catch `Optional(DispatchVnodeEvents[Attribute(8)])` while the full event should be `Optional(DispatchVnodeEvents[Extend(4), Attribute(8)])` occasionally, or rarely but exists that no events catch
    /// A rough way to solve this is call `sleep(1)` before `operation()`.
    /// Use a higher priority queue like `dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)` also helps.
    func testWatchMultiTimes() {
        let cycle = 1000
        var catched = 0
        let pathToWatch = .UserTemporary + "filekit_test_watch"
        // not test a create event
        try? pathToWatch.createFile()
        let operation = {
            do {
                let message = "Testing file system event when writing..."
                try message.writeToPath(pathToWatch, atomically: false)
            } catch {
                XCTFail(String(error))
            }
        }
        for i in 1...cycle {
            // Do watch test
            let watcher = pathToWatch.watch { watch in
                print("\n\n\(watch.currentEvent)\n\n", "index: ", i)
                catched += 1
                // XXX here could check expected event type according to operation
                
                // close in defer is not a better idea, try and see what's the difference
                // comment this to see behave for multi watchs on the same path
                watch.close()
            }
            defer {
                //watcher.close()
            }
            // sleep here most likely solve missing event on a simulator
            //usleep(100000)
            operation()
        }
        // wait asynchronous callbacks end
        sleep(1)
        // Always succes on a real ios device(1000/1000) while most likely fail on a simulator(996/1000)
        // I guest api differ in the simulator and the real device
        XCTAssertEqual(cycle, catched, "should catch \(cycle) times, only \(catched) catched")
    }
    
    func testWatchWithCreate() {
        let pathToWatch = .UserTemporary + "filekit_test_watch"
        try? pathToWatch.deleteFile()
        let expectation = "event"
        let operation = {
            do {
                let message = "Testing file system event when writing..."
                try message.writeToPath(pathToWatch, atomically: false)
                usleep(10000)
                try message.writeToPath(pathToWatch, atomically: false)
            } catch {
                XCTFail(String(error))
            }
        }
        
        // Do watch test
        let expt = self.expectationWithDescription(expectation)
        let watcher = pathToWatch.watch { watch in
            print("\n\n\(watch.currentEvent)\n\n")
            // XXX here could check expected event type according to operation
            if watch.currentEvent != .Create {
                expt.fulfill()
                watch.close()
            }
        }
        defer {
            //watcher.close()
        }
        sleep(1)
        operation()
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    // There is a latency between create event call(on parent write event) and watcher set for path.
    // May miss some events after create.
    func testWatchMultiTimesWithCreate() {
        let cycle = 1000
        var catchedEvent = 0
        var catchedCreate = 0
        let pathToWatch = .UserTemporary + "filekit_test_watch"
        //test a create event
        try? pathToWatch.deleteFile()
        usleep(10000)
        let operation = {
            do {
                let message = "Testing file system event when writing..."
                try message.writeToPath(pathToWatch, atomically: false)
                usleep(10000)
                try message.writeToPath(pathToWatch, atomically: false)
            } catch {
                XCTFail(String(error))
            }
        }
        for i in 1...cycle {
            // Do watch test
            let watcher = pathToWatch.watch(/*queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)*/) { watch in
                print("\n\n\(watch.currentEvent)\n\n", "index: ", i)
                catchedEvent += 1
                // XXX here could check expected event type according to operation
                
                if watch.currentEvent?.contains(.Create) == false {
                    watch.close()
                } else if watch.currentEvent?.contains(.Create) == true {
                    catchedCreate += 1
                }
            }
            defer {
                //watcher.close()
            }
            // start the queue on a device is slow
            if i == 1 { sleep(1) }
            usleep(1000)
            operation()
            usleep(1000)
            try? pathToWatch.deleteFile()
        }
        // wait asynchronous callbacks end
        sleep(1)
        // Always succes on a real ios device(1000/1000) while most likely fail on a simulator(996/1000)
        // I guest api differ in the simulator and the real device
        XCTAssertEqual(cycle * 2, catchedEvent, "should catch events \(cycle * 2) times, only \(catchedEvent) catched")
        XCTAssertEqual(cycle, catchedCreate, "should catch create events \(cycle) times, only \(catchedCreate) catched")
    }
    
    class WatchDelegate: DispatchVnodeWatcherDelegate {
        
        weak var expt: XCTestExpectation?
        
        init(expt: XCTestExpectation?) {
            self.expt = expt
        }
        
        func fsWatcherDidObserveDirectoryChange(watch: DispatchVnodeWatcher) {
            print("\n\nDirectory: \(watch.path) changed \n\n", watch.currentEvent)
        }
        
        func fsWatcherDidObserveCreate(watch: DispatchVnodeWatcher) {
            print("\n\nPath :\(watch.path) created \n\n", watch.currentEvent)
        }
        
        func fsWatcherDidObserveDelete(watch: DispatchVnodeWatcher) {
            print("\n\nPath :\(watch.path) deleted \n\n", watch.currentEvent)
            expt?.fulfill()
        }
        
        func fsWatcherDidObserveAttrib(watch: DispatchVnodeWatcher) {
            print("\n\nPath :\(watch.path) attributed \n\n", watch.currentEvent)
        }
        
        func fsWatcherDidObserveWrite(watch: DispatchVnodeWatcher) {
            print("\n\nPath: \(watch.path) writed \n\n", watch.currentEvent)
        }
    }
    
    func testWatchDelegate() {
        let pathToWatch = .UserTemporary + "filekit_test_watch_file"
        try? pathToWatch.deleteFile()
        let expectation = "event"
        let operation = {
            do {
                try? pathToWatch.createDirectory()
                sleep(1)
                try? pathToWatch.touch()
                let message = "Testing file system event when writing..."
                try message.writeToPath(pathToWatch + "file", atomically: false)
                sleep(1)
                try? pathToWatch.deleteFile()
            } catch {
                XCTFail(String(error))
            }
        }
        // Do watch test
        weak var expt = self.expectationWithDescription(expectation)
        let delegate = WatchDelegate(expt: expt)
        var watcher: DispatchVnodeWatcher? = pathToWatch.watch(delegate: delegate)
        sleep(1)
        operation()
        sleep(1)
        watcher?.close()
        watcher = nil
        self.waitForExpectationsWithTimeout(10, handler: nil)
    }
}
