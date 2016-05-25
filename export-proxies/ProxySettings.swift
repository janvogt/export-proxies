//
//  ProxySettings.swift
//  export-proxies
//
//  Created by Jan Vogt on 16.03.15.
//  Copyright (c) 2015 janvogt. All rights reserved.
//

import SystemConfiguration
import CoreFoundation
import Foundation

private protocol ValueGetter {
    var type: ProxySettings.ProxySetting { get }
    func getValueFromDict(dict: NSDictionary) -> String?
}

class ProxySettings {
    private var settings = [Setting]()
    private struct Setting {
        var name: String
        var value: String
        var allCapitalizations: [Setting] {
            return [Setting(name: name.lowercaseString, value: value),
                Setting(name: name.uppercaseString, value: value),
                Setting(name: name.capitalizedString, value: value)]
        }
        var definition: String {
            get {
                return "\(name)=\"\(value)\""
            }
        }
    }
    private enum ProxySetting {
        case HTTP, HTTPS, FTP, SOCKS, EXCEPTIONS
        var envVariableName: String {
            get {
                var envVar: String
                switch self {
                case .HTTP: envVar = "http"
                case .HTTPS: envVar = "https"
                case .FTP: envVar = "ftp"
                case .SOCKS: envVar = "all"
                case .EXCEPTIONS: envVar = "no"
                }
                return suffixProxy(envVar)
            }
        }
        var protocolName: String? {
            get {
                var proto: String?
                switch self {
                case .HTTP: proto = "http"
                case .HTTPS: proto = "https"
                case .FTP: proto = "ftp"
                case .SOCKS: proto = "socks"
                default: break
                }
                return proto
            }
        }
        private func suffixProxy(label: String) -> String {
            return "\(label)_proxy"
        }
    }
    private struct Protocol: ValueGetter {
        let type: ProxySetting
        let kHost, kPort, kEnabled: String
        func getValueFromDict(dict: NSDictionary) -> String? {
            var value: String?
            switch (type.protocolName, dict[kHost] as! NSString?, dict[kPort] as! NSNumber?, dict[kEnabled] as! NSNumber?) {
            case (.Some(let proto), .Some(let host), .Some(let port), let enabled) where (enabled != nil && enabled! == 1):
                value = "\(proto)://\(host):\(port)"
            default: break
            }
            return value
        }
    }
    private struct Exception: ValueGetter {
        let type = ProxySetting.EXCEPTIONS
        let kExceptions: NSString = kSCPropNetProxiesExceptionsList
        func getValueFromDict(dict: NSDictionary) -> String? {
            var value: String?
            switch (type, dict[kExceptions] as? [String]) {
            case (.EXCEPTIONS, .Some(let exceptions)):
                value = exceptions.map {
                    $0.stringByReplacingOccurrencesOfString("*.", withString: ".")
                }.joinWithSeparator(",")
            default: break
            }
            return value
        }
    }
    private let protocols: [ValueGetter] = [
        Protocol(type: .HTTP,
            kHost: kSCPropNetProxiesHTTPProxy as String,
            kPort: kSCPropNetProxiesHTTPPort as String,
            kEnabled: kSCPropNetProxiesHTTPEnable as String),
        Protocol(type: .HTTPS,
            kHost: kSCPropNetProxiesHTTPSProxy as String,
            kPort: kSCPropNetProxiesHTTPSPort as String,
            kEnabled: kSCPropNetProxiesHTTPSEnable as String),
        Protocol(type: .FTP,
            kHost: kSCPropNetProxiesFTPProxy as String,
            kPort: kSCPropNetProxiesFTPPort as String,
            kEnabled: kSCPropNetProxiesFTPEnable as String),
        Protocol(type: .SOCKS,
            kHost: kSCPropNetProxiesSOCKSProxy as String,
            kPort: kSCPropNetProxiesSOCKSPort as String,
            kEnabled: kSCPropNetProxiesSOCKSEnable as String),
        Exception()
    ]
    init?() {
        if let store = SCDynamicStoreCreateWithOptions(nil, "app", nil, nil, nil) {
            if let osxProxySettings: NSDictionary = SCDynamicStoreCopyProxies(store) {
                for proto in protocols {
                    switch (proto.type.envVariableName, proto.getValueFromDict(osxProxySettings)) {
                    case (let name, .Some(let value)):
                        let setting = Setting(name: name, value: value)
                        settings.appendContentsOf(setting.allCapitalizations)
                    default: break
                    }
                }
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    var exports: String {
        get {
            return settings.map { "export \($0.definition)" }.joinWithSeparator("\n")
        }
    }
}