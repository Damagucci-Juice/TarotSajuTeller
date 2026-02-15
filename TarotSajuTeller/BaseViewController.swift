//
//  ViewController.swift
//  TarotSajuTeller
//
//  Created by Gucci on 2/15/26.
//

import UIKit
import Alamofire
import SnapKit
import Then
import Toast
import Kingfisher
import RxSwift
import RxCocoa
import RxRelay

// MARK: - BASE VIEW CONTROLLER

protocol BasicViewProtocol {
    func setupHierarchy()
    func setupLayout()
    func setupView()
}

class BaseViewController: UIViewController, BasicViewProtocol {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupHierarchy()
        setupLayout()
        setupView()
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func setupHierarchy() {
    }

    func setupLayout() {
    }

    func setupView() {
        view.backgroundColor = .white
        navigationItem.title = "Base"
    }
}

// MARK: - MAIN VIEW CONTROLLER

final class MainViewController: BaseViewController {

    private let callButton = UIButton().then { btn in
        btn.setTitle("요청하기", for: .normal)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchSolar()
    }

    override func setupHierarchy() {
        super.setupHierarchy()
        view.addSubview(callButton)
    }

    override func setupLayout() {
        super.setupLayout()
        callButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    override func setupView() {
        super.setupView()
        navigationItem.title = "Saju"

        callButton.backgroundColor = .yellow
        callButton.addTarget(self, action: #selector(callButtonAction), for: .touchUpInside)
    }

    @objc
    private func callButtonAction() {
        fetchSolar()
    }

    private func fetchSolar() {
        let solarRequestDto = SolarRequestDTO(solarDay: 3, solarMonth: 8, solarYear: 1995)
        NetworkService.shared.fetch(
            .solarToLuna(requestDto: solarRequestDto),
            type: String.self) { result in
                switch result {
                case .success(let answer):
                    self.view.makeToast(answer)
                case .failure(let error):
                    self.view.makeToast(error.localizedDescription)
                }
        }
    }
}

// MARK: - Network Service

enum Environment {
    static var baseURL: String {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "BaseURL") as? String else {
            fatalError("BaseURL not found in Info.plist")
        }
        return url
    }

    static var clientKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ClientKey") as? String else {
            fatalError("ClientKey not found in Info.plist")
        }
        return key
    }
}

struct SolarRequestDTO {
    let solarDay: Int
    let solarMonth: Int
    let solarYear: Int
}

struct LunaResponseDTO: Decodable {
    let header: String
    let body: LunaItemsDTO
}

struct LunaItemsDTO: Decodable {
    let items: LunaInfoDTO
}

struct LunaInfoDTO: Decodable {
    let lunDay, lunIljin, lunLeapmonth, lunMonth: String
    let lunNday: Int
    let lunSecha, lunWolgeon: String
    let lunYear: Int
    let solDay: String
    let solJd: Int
    let solLeapyear, solMonth, solWeek: String
    let solYear: Int
}

enum TaroRouter: URLRequestConvertible {
    case solarToLuna(requestDto: SolarRequestDTO)

    var baseURL: String {
        Environment.baseURL
    }

    var path: String {
        switch self {
        case .solarToLuna:
            return "/getLunCalInfo"
        }
    }

    var method: HTTPMethod {
        .get
    }

    var param: Parameters {
        switch self {
        case .solarToLuna(let requestDto):
            [
                "solYear": requestDto.solarYear,
                "solMonth": requestDto.solarMonth < 10 ? "0\(requestDto.solarMonth)" : "\(requestDto.solarMonth)",
                "solDay": requestDto.solarDay < 10 ? "0\(requestDto.solarDay)" : "\(requestDto.solarDay)",
                "ServiceKey": Environment.clientKey,
                "_type": "json"
            ]
        }
    }

    func asURLRequest() throws -> URLRequest {
        print("URL", baseURL)
        let url = try baseURL.asURL()
        var urlRequest = URLRequest(url: url.appendingPathComponent(path))
        urlRequest.httpMethod = method.rawValue
        urlRequest.timeoutInterval = 10
        return try URLEncoding.default.encode(urlRequest, with: param)
    }
}

enum SolarError: Error {
    case unknown
}

final class NetworkService {
    static let shared = NetworkService()
    private init() { }

    func fetch<T>(_ api: TaroRouter, type: T.Type, completion: @escaping (Result<String, SolarError>) -> Void) {
        do {
            let urlRequest = try api.asURLRequest()


            AF.request(urlRequest)
                .validate()
                .responseString { response in
                    print(response)
                    switch response.result {
                    case .success(let answer):
                        completion(.success(answer))
                    case .failure:
                        completion(.failure(.unknown))
                    }
                }
        } catch {
            completion(.failure(.unknown))
        }
    }
}
