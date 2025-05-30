import SwiftUI
import Demark

#if os(iOS)
extension ContentView {
    var iOSLayout: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // HTML Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("HTML Input", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.headline)
                            
                            Spacer()
                            
                            sampleHTMLMenu
                        }
                        
                        TextEditor(text: $htmlInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Options Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Conversion Options")
                            .font(.headline)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Heading Style")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Heading Style", selection: $options.headingStyle) {
                                    Text("ATX (# Heading)").tag(DemarkHeadingStyle.atx)
                                    Text("Setext").tag(DemarkHeadingStyle.setext)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("List Marker")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("List Marker", selection: $options.bulletListMarker) {
                                    Text("-").tag("-")
                                    Text("*").tag("*")
                                    Text("+").tag("+")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Code Blocks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("Code Blocks", selection: $options.codeBlockStyle) {
                                    Text("Fenced").tag(DemarkCodeBlockStyle.fenced)
                                    Text("Indented").tag(DemarkCodeBlockStyle.indented)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Convert Button
                    Button(action: convertHTML) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Convert to Markdown")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConverting || htmlInput.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isConverting || htmlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    // Output Section
                    if !markdownOutput.isEmpty || conversionError != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Markdown Output", systemImage: "doc.text")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if !markdownOutput.isEmpty {
                                    Button(action: copyMarkdown) {
                                        Image(systemName: "doc.on.doc")
                                    }
                                }
                            }
                            
                            if let error = conversionError {
                                Text("Error: \(error)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            if !markdownOutput.isEmpty {
                                ScrollView {
                                    Text(markdownOutput)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                }
                                .frame(minHeight: 200)
                                .background(Color(.tertiarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Demark")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
    }
}
#endif