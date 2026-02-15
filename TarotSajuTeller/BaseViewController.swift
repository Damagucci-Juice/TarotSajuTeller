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

    private let resultLabel = UILabel().then { lbl in
        lbl.textColor = .black
        lbl.numberOfLines = 0
    }

    private let callButton = UIButton().then { btn in
        btn.setTitle("요청하기", for: .normal)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        fetchSolar()
    }

    override func setupHierarchy() {
        super.setupHierarchy()
        view.addSubview(resultLabel)
        view.addSubview(callButton)
    }

    override func setupLayout() {
        super.setupLayout()
        resultLabel.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview().inset(16)
            make.bottom.equalTo(callButton.snp.top).inset(16)
        }

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
            type: SolarToLunaResponse.self) { result in
                switch result {
                case .success(let answer):
                    self.resultLabel.text = answer.response.body.items.item.description
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

struct SolarToLunaResponse: Decodable {
    let response: ResponseData
}

struct ResponseData: Decodable {
    let header: ResponseHeader
    let body: ResponseBody
}

struct ResponseHeader: Decodable {
    let resultCode: String
    let resultMsg: String
}

struct ResponseBody: Decodable {
    let items: ItemContainer
    let numOfRows: Int
    let pageNo: Int
    let totalCount: Int
}

struct ItemContainer: Decodable {
    let item: LunaItem
}

struct LunaItem: Decodable, CustomStringConvertible {
    let lunYear: Int
    let lunMonth: String
    let lunDay: String
    let lunIljin: String      // "병인(丙寅)" -> 한자가 포함된 문자열
    let lunSecha: String      // "을해(乙亥)"
    let lunWolgeon: String    // "갑신(甲申)"
    let lunLeapmonth: String
    let lunNday: Int
    let solYear: Int
    let solMonth: String
    let solDay: String
    let solWeek: String
    let solLeapyear: String
    let solJd: Int

    var description: String {
            return """
            --- 🗓️ 변환 결과 ---
            [양력] \(solYear)년 \(solMonth)월 \(solDay)일 (\(solWeek)요일)
            [음력] \(lunYear)년 \(lunMonth)월 \(lunDay)일 (\(lunLeapmonth == "평" ? "평달" : "윤달"))

            --- 🔮 사주 원국 (삼주) ---
            년주(年柱): \(lunSecha)
            월주(月柱): \(lunWolgeon)
            일주(日柱): \(lunIljin)

            * 시주(時柱)는 태어난 시간을 입력하면 계산이 가능합니다.
            -------------------
            """
        }
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

    func fetch<T>(_ api: TaroRouter,
                  type: T.Type,
                  completion: @escaping (Result<T, SolarError>) -> Void) where T: Decodable {
        do {
            AF.request(try api.asURLRequest())
                .validate()
                .responseDecodable(of: type.self) { response in
                    switch response.result {
                    case .success(let responseDto):
                        completion(.success(responseDto))
                    case .failure:
                        completion(.failure(.unknown))
                    }
                }
        } catch {
            completion(.failure(.unknown))
        }
    }
}
