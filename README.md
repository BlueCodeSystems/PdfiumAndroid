# Pdfium Android binding with Bitmap rendering
Uses pdfium library [from AOSP](https://android.googlesource.com/platform/external/pdfium/)

The demo app (for not modified lib) is [here](https://github.com/mshockwave/PdfiumAndroid-Demo-App)

Forked for use with [AndroidPdfViewer](https://github.com/barteksc/AndroidPdfViewer) project.

API is highly compatible with original version, only additional methods were created.

# This repo was forked from [PdfiumAndroid](https://github.com/barteksc/PdfiumAndroid)

The purpose is to remove old support libraries so we no longer need to use jetifier.

It will be used with the forked [AndroidPdFViewer](https://github.com/mhiew/AndroidPdfViewer)

## Modern Android Upgrade (2.0.0
This fork modernizes the build and publishing setup to current Android tooling while preserving the original API.

- Gradle: 8.7
- Android Gradle Plugin (AGP): 8.6.0
- Java: 17
- compileSdk: 35
- targetSdk: 35
- minSdk: 28
- Build Tools: 35.0.0
- Android NDK: 26.2.11394342

Publishing is configured via `maven-publish`. For JitPack builds, we publish to Maven Local and skip GPG signing (see Build Flags).

## What's new in 1.9.2
This is functionally the same as 1.9.1 just fixing some documentation on maven central

## What's new in 1.9.1
* Update Gradle plugins and configurations
* Update compile sdk to 31
* Change minimum SDK to 19
* Remove support-v4 library
* Drop support for mips

## What's new in 1.9.0?
* Updated Pdfium library to 7.1.2_r36
* Changed `gnustl_static` to `c++_shared`
* Update Gradle plugins
* Update compile SDK and support library to 26
* Change minimum SDK to 14
* Add support for mips64

## Installation
Add to your Gradle build:

1) Repositories (top-level `settings.gradle` or `build.gradle`):
```
maven { url 'https://jitpack.io' }
```

2) Dependency (module `build.gradle`):
```
implementation 'com.github.BlueCodeSystems:pdfium-android:<version>'
```

Replace `<version>` with the JitPack tag or commit you want to consume.

Library is available in jcenter and Maven Central repositories.

## Maven Central bundle (manual upload)

Use the helper script to build, sign, checksum, and zip a Central-ready bundle without publishing:

`./scripts/central-bundle.sh`

Requirements:
- Set a release `VERSION_NAME` (no `SNAPSHOT`) in `gradle.properties`.
- GPG available or provide in-memory signing props (`-PsigningKey`, `-PsigningPassword`).

Outputs a zip at `build/distributions/central-bundle-<artifactId>-<version>.zip` suitable for upload at `https://s01.oss.sonatype.org/`.

## JitPack Build Flags
This repository uses the following flags to ensure successful JitPack builds without requiring signing keys:

- `-PskipSigning=true`: Disables GPG signing for publishing tasks on CI.
- `-PGROUP=com.github.<owner>`: Sets the Maven group to the GitHub owner namespace.
- `-PVERSION_NAME=${VERSION}`: Uses the JitPack-provided version (tag/commit).

On JitPack, we run:
```
./gradlew --no-daemon -x test -x lint \
  -PskipSigning=true \
  -PGROUP=com.github.${OWNER} \
  -PVERSION_NAME=${VERSION} \
  publishToMavenLocal
```

This publishes the AAR and POM to `~/.m2`, which JitPack then picks up to produce the final artifacts.

## Methods inconsistency
Version 1.8.0 added method for getting page size - `PdfiumCore#getPageSize(...)`.
It is important to note, that this method does not require page to be opened. However, there are also
old `PdfiumCore#getPageWidth(...)`, `PdfiumCore#getPageWidthPoint(...)`, `PdfiumCore#getPageHeight()`
and `PdfiumCore#getPageHeightPoint()` which require page to be opened.

This inconsistency will be resolved in next major version, which aims to redesign API.

## Reading links
Version 1.8.0 introduces `PdfiumCore#getPageLinks(PdfDocument, int)` method, which allows to get list
of links from given page. Links are returned as `List` of type `PdfDocument.Link`.
`PdfDocument.Link` holds destination page (may be null), action URI (may be null or empty)
and link bounds in document page coordinates. To map page coordinates to screen coordinates you may use
`PdfiumCore#mapRectToDevice(...)`. See `PdfiumCore#mapPageCoordsToDevice(...)` for parameters description.

Sample usage:
``` java
PdfiumCore core = ...;
PdfDocument document = ...;
int pageIndex = 0;
core.openPage(document, pageIndex);
List<PdfDocument.Link> links = core.getPageLinks(document, pageIndex);
for (PdfDocument.Link link : links) {
    RectF mappedRect = core.mapRectToDevice(document, pageIndex, ..., link.getBounds())

    if (clickedArea(mappedRect)) {
        String uri = link.getUri();
        if (link.getDestPageIdx() != null) {
            // jump to page
        } else if (uri != null && !uri.isEmpty()) {
            // open URI using Intent
        }
    }
}

```

## Simple example
``` java
void openPdf() {
    ImageView iv = (ImageView) findViewById(R.id.imageView);
    ParcelFileDescriptor fd = ...;
    int pageNum = 0;
    PdfiumCore pdfiumCore = new PdfiumCore(context);
    try {
        PdfDocument pdfDocument = pdfiumCore.newDocument(fd);

        pdfiumCore.openPage(pdfDocument, pageNum);

        int width = pdfiumCore.getPageWidthPoint(pdfDocument, pageNum);
        int height = pdfiumCore.getPageHeightPoint(pdfDocument, pageNum);

        // ARGB_8888 - best quality, high memory usage, higher possibility of OutOfMemoryError
        // RGB_565 - little worse quality, twice less memory usage
        Bitmap bitmap = Bitmap.createBitmap(width, height,
                Bitmap.Config.RGB_565);
        pdfiumCore.renderPageBitmap(pdfDocument, bitmap, pageNum, 0, 0,
                width, height);
        //if you need to render annotations and form fields, you can use
        //the same method above adding 'true' as last param

        iv.setImageBitmap(bitmap);

        printInfo(pdfiumCore, pdfDocument);

        pdfiumCore.closeDocument(pdfDocument); // important!
    } catch(IOException ex) {
        ex.printStackTrace();
    }
}

public void printInfo(PdfiumCore core, PdfDocument doc) {
    PdfDocument.Meta meta = core.getDocumentMeta(doc);
    Log.e(TAG, "title = " + meta.getTitle());
    Log.e(TAG, "author = " + meta.getAuthor());
    Log.e(TAG, "subject = " + meta.getSubject());
    Log.e(TAG, "keywords = " + meta.getKeywords());
    Log.e(TAG, "creator = " + meta.getCreator());
    Log.e(TAG, "producer = " + meta.getProducer());
    Log.e(TAG, "creationDate = " + meta.getCreationDate());
    Log.e(TAG, "modDate = " + meta.getModDate());

    printBookmarksTree(core.getTableOfContents(doc), "-");

}

public void printBookmarksTree(List<PdfDocument.Bookmark> tree, String sep) {
    for (PdfDocument.Bookmark b : tree) {

        Log.e(TAG, String.format("%s %s, p %d", sep, b.getTitle(), b.getPageIdx()));

        if (b.hasChildren()) {
            printBookmarksTree(b.getChildren(), sep + "-");
        }
    }
}

```
## Build native part
Go to `PROJECT_PATH/src/main/jni` and run command `$ ndk-build`.
This step may be executed only once, every future `.aar` build will use generated libs.
