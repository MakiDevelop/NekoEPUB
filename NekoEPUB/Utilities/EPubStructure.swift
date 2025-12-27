//
//  EPubStructure.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import Foundation

struct EPubStructure {
    static func mimetype() -> String {
        "application/epub+zip"
    }

    static func containerXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
    }

    static func contentOPF(metadata: EPubMetadata, images: [ImageItem]) -> String {
        let manifestItems = images.enumerated().map { index, image in
            let imageId = "image\(String(format: "%03d", index + 1))"
            let pageId = "page\(String(format: "%03d", index + 1))"
            let ext = image.fileExtension
            let mimeType = mimeTypeForExtension(ext)

            return """
                <item id="\(imageId)" href="Images/\(imageId).\(ext)" media-type="\(mimeType)"/>
                <item id="\(pageId)" href="Text/\(pageId).xhtml" media-type="application/xhtml+xml"/>
            """
        }.joined(separator: "\n    ")

        let spineItems = images.enumerated().map { index, _ in
            let pageId = "page\(String(format: "%03d", index + 1))"
            return """
                <itemref idref="\(pageId)"/>
            """
        }.joined(separator: "\n        ")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="BookId">\(metadata.identifier)</dc:identifier>
                <dc:title>\(metadata.title)</dc:title>
                <dc:creator>\(metadata.author)</dc:creator>
                <dc:language>\(metadata.language)</dc:language>
                <meta property="dcterms:modified">\(metadata.date)</meta>
            </metadata>
            <manifest>
                <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
                \(manifestItems)
            </manifest>
            <spine toc="ncx">
                \(spineItems)
            </spine>
        </package>
        """
    }

    static func tocNCX(metadata: EPubMetadata, pageCount: Int) -> String {
        let navPoints = (0..<pageCount).map { index in
            let pageId = "page\(String(format: "%03d", index + 1))"
            let playOrder = index + 1

            return """
                <navPoint id="\(pageId)" playOrder="\(playOrder)">
                    <navLabel><text>Page \(playOrder)</text></navLabel>
                    <content src="Text/\(pageId).xhtml"/>
                </navPoint>
            """
        }.joined(separator: "\n        ")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
            <head>
                <meta name="dtb:uid" content="\(metadata.identifier)"/>
                <meta name="dtb:depth" content="1"/>
            </head>
            <docTitle><text>\(metadata.title)</text></docTitle>
            <navMap>
                \(navPoints)
            </navMap>
        </ncx>
        """
    }

    static func imagePageXHTML(imageFileName: String, pageNumber: Int) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
            <title>Page \(pageNumber)</title>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    text-align: center;
                }
                img {
                    max-width: 100%;
                    max-height: 100vh;
                    display: block;
                    margin: 0 auto;
                }
            </style>
        </head>
        <body>
            <img src="../Images/\(imageFileName)" alt="Page \(pageNumber)"/>
        </body>
        </html>
        """
    }

    private static func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        default:
            return "application/octet-stream"
        }
    }
}
