//
//  MainTabView.swift
//  NekoEPUB
//
//  Created by Claude on 2025/12/24.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ImagesToEPubView()
                .tabItem {
                    Label("圖片轉 ePub", systemImage: "photo.on.rectangle")
                }

            EPubToImagesView()
                .tabItem {
                    Label("ePub 轉圖片", systemImage: "book.closed")
                }

            EPubCompressionView()
                .tabItem {
                    Label("壓縮 ePub", systemImage: "archivebox")
                }

            BatchConversionView()
                .tabItem {
                    Label("批次轉檔", systemImage: "folder.fill.badge.gearshape")
                }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    MainTabView()
}
