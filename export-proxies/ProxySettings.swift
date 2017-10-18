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
    func getValueFromDict(_ dict: NSDictionary) -> String?
}

class ProxySettings {
    fileprivate var settings = [Setting]()
    fileprivate struct Setting {
        var name: String
        var value: String
        var allCapitalizations: [Setting] {
            return [Setting(name: name.lowercased(), value: value),
                Setting(name: name.uppercased(), value: value),
                Setting(name: name.capitalized, value: value)]
        }
        var definition: String {
            get {
                return "\(name)=\"\(value)\""
            }
        }
    }
    fileprivate enum ProxySetting {
        case http, https, ftp, socks, exceptions
        var envVariableName: String {
            get {
                var envVar: String
                switch self {
                case .http: envVar = "http"
                case .https: envVar = "https"
                case .ftp: envVar = "ftp"
                case .socks: envVar = "all"
                case .exceptions: envVar = "no"
                }
                return suffixProxy(envVar)
            }
        }
        var protocolName: String? {
            get {
                var proto: String?
                switch self {
                case .http: proto = "http"
                case .https: proto = "https"
                case .ftp: proto = "ftp"
                case .socks: proto = "socks"
                default: break
                }
                return proto
            }
        }
        fileprivate func suffixProxy(_ label: String) -> String {
            return "\(label)_proxy"
        }
    }
    fileprivate struct ProxyProtocol: ValueGetter {
        let type: ProxySetting
        let kHost, kPort, kEnabled: String
        func getValueFromDict(_ dict: NSDictionary) -> String? {
            var value: String?
            switch (type.protocolName, dict[kHost] as! NSString?, dict[kPort] as! NSNumber?, dict[kEnabled] as! NSNumber?) {
            case (.some(let proto), .some(let host), .some(let port), let enabled) where (enabled != nil && enabled! == 1):
                value = "\(proto)://\(host):\(port)"
            default: break
            }
            return value
        }
    }
    fileprivate struct Exception: ValueGetter {
        let type = ProxySetting.exceptions
        let kExceptions: NSString = kSCPropNetProxiesExceptionsList
        func getValueFromDict(_ dict: NSDictionary) -> String? {
            var value: String?
            switch (type, dict[kExceptions] as? [String]) {
            case (.exceptions, .some(let exceptions)):
                value = exceptions.map {
                    $0.replacingOccurrences(of: "*.", with: ".")
                }.joined(separator: ",")
            default: break
            }
            return value
        }
    }
    fileprivate let protocols: [ValueGetter] = [
        ProxyProtocol(type: .http,
            kHost: kSCPropNetProxiesHTTPProxy as String,
            kPort: kSCPropNetProxiesHTTPPort as String,
            kEnabled: kSCPropNetProxiesHTTPEnable as String),
        ProxyProtocol(type: .https,
            kHost: kSCPropNetProxiesHTTPSProxy as String,
            kPort: kSCPropNetProxiesHTTPSPort as String,
            kEnabled: kSCPropNetProxiesHTTPSEnable as String),
        ProxyProtocol(type: .ftp,
            kHost: kSCPropNetProxiesFTPProxy as String,
            kPort: kSCPropNetProxiesFTPPort as String,
            kEnabled: kSCPropNetProxiesFTPEnable as String),
        ProxyProtocol(type: .socks,
            kHost: kSCPropNetProxiesSOCKSProxy as String,
            kPort: kSCPropNetProxiesSOCKSPort as String,
            kEnabled: kSCPropNetProxiesSOCKSEnable as String),
        Exception()
    ]
    init?() {
        if let store = SCDynamicStoreCreateWithOptions(nil, "app" as CFString, nil, nil, nil) {
            if let osxProxySettings: NSDictionary = SCDynamicStoreCopyProxies(store) {
                for proto in protocols {
                    switch (proto.type.envVariableName, proto.getValueFromDict(osxProxySettings)) {
                    case (let name, .some(let value)):
                        let setting = Setting(name: name, value: value)
                        settings.append(contentsOf: setting.allCapitalizations)
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
            return settings.map { "export \($0.definition)" }.joined(separator: "\n")
        }
    }
}
