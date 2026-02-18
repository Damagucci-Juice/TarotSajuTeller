//
//  ViewController.swift
//  TarotSajuTeller
//
//  Created by Gucci on 2/15/26.
//
// swiftlint:disable file_length

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
// MARK: - MAIN VIEW CONTROLLER
final class MainViewController: BaseViewController {

    private let resultLabel = UILabel().then { lbl in
        lbl.textColor = .black
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        lbl.text = "프로필을 입력해주세요"
    }

    private let callButton = UIButton().then { btn in
        btn.setTitle("3카드 뽑기", for: .normal)
        btn.setTitleColor(.black, for: .normal)
        btn.backgroundColor = .yellow
        btn.layer.cornerRadius = 100
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 💡 프로필 변경 감지 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBirthDateChanged),
            name: NSNotification.Name("BirthDateChanged"), object: nil)
        fetchSolarIfNeeded()
    }

    override func setupHierarchy() {
        view.addSubview(resultLabel)
        view.addSubview(callButton)
    }

    override func setupLayout() {
        resultLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(50)
            make.horizontalEdges.equalToSuperview().inset(20)
        }

        callButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(200)
        }
    }

    override func setupView() {
        super.setupView()
        navigationItem.title = "Saju"

        let profileButton = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain,
            target: self,
            action: #selector(profileButtonTapped)
        )
        profileButton.tintColor = .black
        navigationItem.rightBarButtonItem = profileButton

        callButton.addTarget(self, action: #selector(callButtonAction), for: .touchUpInside)
    }

    @objc private func handleBirthDateChanged() {
        fetchSolarIfNeeded() // 알림 받으면 갱신
    }

    private func fetchSolarIfNeeded() {
        // API 통신 후 저장된 실제 일주(sajuDay) 정보를 가져옴
        if let realIljin = UserDefaults.standard.string(forKey: UDKey.sajuDay),
           let name = UserDefaults.standard.string(forKey: UDKey.name) {
            // 예: "Gucci님은 현재 [병인(丙寅)] 일주의 기운이 흐르고 있습니다."
            self.resultLabel.text = "“\(name)”님은 현재 [\(realIljin)] 일주의 기운이 흐르고 있습니다."
        } else {
            showProfileRequiredAlert()
        }
    }

    private func showProfileRequiredAlert() {
        let alert = UIAlertController(title: "프로필 미설정", message: "사주 분석을 위해 프로필을 완성해주세요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "설정하러 가기", style: .default) { [weak self] _ in
            self?.profileButtonTapped()
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func profileButtonTapped() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
    }

    @objc private func callButtonAction() {
        if UserDefaults.standard.string(forKey: UDKey.sajuDay) == nil {
            showProfileRequiredAlert()
        } else {
            let selectVC = SelectCardViewController()
            navigationController?.pushViewController(selectVC, animated: true)
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

// MARK: - TAROT Router

enum TarotRouter: URLRequestConvertible {
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

// MARK: - Network Service

final class NetworkService {
    static let shared = NetworkService()
    private init() { }

    func fetch<T>(_ api: TarotRouter,
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

protocol Reusable: AnyObject {
    static var identifier: String { get }
}

extension Reusable {
    static var identifier: String {
        return String(describing: self)
    }
}

extension UIViewController: Reusable { }

extension UITableViewCell: Reusable { }

extension UICollectionViewCell: Reusable { }

struct LocalImageProvider: ImageDataProvider {
    let imageName: String

    var cacheKey: String {
        return imageName
    }

    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = UIImage(named: imageName),
               let data = image.pngData() {
                handler(.success(data))
            } else {
                handler(.failure(NSError(domain: "LocalImageProvider", code: -1, userInfo: nil)))
            }
        }
    }
}

// MARK: - CardCollectionViewCell

final class CardCollectionViewCell: UICollectionViewCell {

    private var isFlipped = false
    private var cardData: TarotCard? // 카드 데이터를 저장할 변수 추가

    // 뒷면 이미지뷰 (공통 이미지)
    private let backImageView = UIImageView().then {
        $0.image = UIImage(named: "tarot_back.jpg")
        $0.contentMode = .scaleAspectFill
        $0.layer.cornerRadius = 12
        $0.clipsToBounds = true
    }

    // 앞면 이미지뷰 (카드별 고유 이미지)
    private let frontImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFill
        $0.layer.cornerRadius = 12
        $0.clipsToBounds = true
        $0.isHidden = true // 처음엔 숨김
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupHierarchy()
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupHierarchy() {
        contentView.addSubview(frontImageView)
        contentView.addSubview(backImageView)
    }

    private func setupLayout() {
        backImageView.snp.makeConstraints { $0.edges.equalToSuperview() }
        frontImageView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func flipCard() {
        guard !isFlipped else { return }

        // 💡 UIView.transition을 사용한 카드 뒤집기 애니메이션
        let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromRight, .showHideTransitionViews]

        UIView.transition(
            from: backImageView,
            to: frontImageView,
            duration: 0.6,
            options: transitionOptions) { [weak self] _ in
                self?.isFlipped = true
            }
    }
    // Cell의 configure 메서드
    func configure(with card: TarotCard, isSelected: Bool) {
        self.cardData = card
        self.isFlipped = isSelected

        // Kingfisher 캐시를 활용한 로컬 이미지 다운샘플링
        let provider = LocalImageProvider(imageName: card.imageName)
        let processor = DownsamplingImageProcessor(size: self.bounds.size)

        frontImageView.kf.indicatorType = .activity
        frontImageView.kf.setImage(
            with: .provider(provider),
            options: [
                .processor(processor),
                .scaleFactor(UIScreen.main.scale),
                .transition(.fade(0.2)),
                .cacheSerializer(FormatIndicatedCacheSerializer.png),
                .cacheOriginalImage  // 원본도 캐싱
            ]
        )

        if card.isReversed {
            frontImageView.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            frontImageView.transform = .identity
        }

        if isSelected {
            backImageView.isHidden = true
            frontImageView.isHidden = false
        } else {
            backImageView.isHidden = false
            frontImageView.isHidden = true
        }
    }

    // 💡 셀이 재사용될 때 초기화 처리
    override func prepareForReuse() {
        super.prepareForReuse()
        isFlipped = false
        backImageView.isHidden = false
        frontImageView.isHidden = true
        frontImageView.transform = .identity // 회전값 초기화
    }
}

// MARK: - SelectCardViewController

final class SelectCardViewController: BaseViewController {

    private let inputTextField = UITextField().then { tfd in
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        tfd.leftView = paddingView
        tfd.leftViewMode = .always
        tfd.placeholder = "진심을 담아 질문을 입력하세요"
        tfd.backgroundColor = .secondarySystemBackground
        tfd.layer.cornerRadius = 8
        tfd.returnKeyType = .done
    }

    private let sowanLabel = UILabel().then { lbl in
        lbl.textColor = .black
        lbl.font = .systemFont(ofSize: 16)
        lbl.isHidden = true
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
    }

    private let cardCollectionView = UICollectionView(frame: .zero, collectionViewLayout: .init())
    private let contentView = UIView().then { view in
        view.backgroundColor = .lightGray
    }

    private var sowan: String?
    private var selectedCards: [TarotCard] = []
    private let tarotCards = TarotData.allCards.shuffled()

    // 화면이 나타날 때 포커싱 (키보드 올리기)
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        inputTextField.becomeFirstResponder()
    }

    override func setupHierarchy() {
        super.setupHierarchy()
        view.addSubview(inputTextField)
        view.addSubview(cardCollectionView)
        view.addSubview(sowanLabel)
        cardCollectionView.addSubview(contentView)
    }

    override func setupLayout() {
        super.setupLayout()
        inputTextField.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(20)
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top).inset(16)
            make.height.equalTo(50)
        }

        cardCollectionView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(sowanLabel.snp.top)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalTo(cardCollectionView.contentLayoutGuide)
            make.height.equalTo(cardCollectionView.frameLayoutGuide)
        }

        sowanLabel.snp.makeConstraints { make in
            make.bottom.horizontalEdges.equalToSuperview().inset(32)
        }
    }

    override func setupView() {
        super.setupView()
        inputTextField.delegate = self

        // 콜렉션뷰 설정
        cardCollectionView.delegate = self
        cardCollectionView.dataSource = self
        cardCollectionView.register(
            CardCollectionViewCell.self,
            forCellWithReuseIdentifier: CardCollectionViewCell.identifier
        )
        cardCollectionView.isHidden = true // 처음엔 숨김
        cardCollectionView.showsHorizontalScrollIndicator = false
        cardCollectionView.showsVerticalScrollIndicator = false

        view.backgroundColor = .systemBackground
    }

    // 리턴 시 동작 보완
    private func showCardSelection() {
        inputTextField.isHidden = true
        cardCollectionView.isHidden = false
        sowanLabel.isHidden = false
        sowanLabel.text = "\(sowan ?? "")"
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        cardCollectionView.collectionViewLayout = layout()
    }

    func layout() -> UICollectionViewFlowLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let hInset = 5.0
        let vInset = 5.0
        let lineSpacing = 4.0
        let interSpacing = 4.0

        layout.minimumLineSpacing = lineSpacing
        layout.minimumInteritemSpacing = interSpacing
        let itemPerRow = 5.0
        let itemPerCol = 5.0
        let screenWidth = view.window?.windowScene?.screen.bounds.width ?? .zero
        let availableWidth = screenWidth - (hInset * 2) - (interSpacing * (itemPerRow - 1))
        let cellWidth = availableWidth / itemPerRow

        let collectionViewHeight = cardCollectionView.bounds.height
        let availableHeight = collectionViewHeight - (vInset * 2) - (lineSpacing * (itemPerCol))
        let cellHeight = availableHeight / itemPerCol - 3
        layout.itemSize = CGSize(
            width: cellWidth,
            height: cellHeight)
        layout.sectionInset = UIEdgeInsets(top: vInset, left: hInset, bottom: vInset, right: hInset)
        return layout
    }
}

// MARK: - CollectionView DataSource & Delegate
extension SelectCardViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        tarotCards.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CardCollectionViewCell.identifier, for: indexPath) as? CardCollectionViewCell
        else { return UICollectionViewCell() }

        // 현재 인덱스가 선택된 목록에 있는지 확인하여 전달
        let card = tarotCards[indexPath.item]
        let isSelected = selectedCards.contains(card)
        cell.configure(with: card, isSelected: isSelected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 이미 선택된 카드라면 무시
        let card = tarotCards[indexPath.item]
        if selectedCards.contains(card) { return }

        guard selectedCards.count < 3 else {
            print("더 이상 고를 수 없어요")
            return
        }

        guard let cell = collectionView.cellForItem(at: indexPath) as? CardCollectionViewCell else { return }

        // 1. 상태 업데이트 및 애니메이션 실행
        selectedCards.append(card)
        cell.flipCard()

        print("\(indexPath.item + 1)번째 카드가 선택되었습니다.")

        if selectedCards.count == 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                print("3개 선택 완료!")
                guard let self else { return }
                let vc = TarotResultViewController(cards: self.selectedCards, hope: sowan ?? "")
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
}

// MARK: - TextField Delegate
extension SelectCardViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.sowan = textField.text
        textField.resignFirstResponder()
        showCardSelection() // 카드 화면 표시 함수 호출
        return true
    }
}

// MARK: - Tarot

enum TarotSuit: String, CaseIterable {
    case major = "메이저"
    case wands = "완드"
    case cups = "컵"
    case swords = "소드"
    case pentacles = "펜타클"
}

struct TarotCard: Hashable, Identifiable {
    let id: Int
    let name: String
    let suit: TarotSuit
    var isReversed: Bool = false // 역방향 여부 (기본값 정방향)
    var description: String = "" // 해석 내용

    // 이미지 파일명 자동 생성: "tarot_0.jpg" 형식
    var imageName: String {
        return "tarot_\(id).jpg"
    }
}
struct TarotData {
    static let allCards: [TarotCard] = {
        var cards: [TarotCard] = []

        // 1. 메이저 아르카나 이름 정의 (0~21)
        let majorNames = [
            "광대", "마법사", "고위 여사제", "여황제", "황제",
            "교황", "연인", "전차", "힘", "은둔자",
            "운명의 수레바퀴", "정의", "매달린 사람", "죽음", "절제",
            "악마", "탑", "별", "달", "태양", "심판", "세계"
        ]

        for (index, name) in majorNames.enumerated() {
            cards.append(TarotCard(id: index, name: name, suit: .major))
        }

        // 2. 마이너 아르카나 생성 (22~77)
        let minorSuits: [TarotSuit] = [.wands, .cups, .swords, .pentacles]
        let ranks = ["Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Page", "Knight", "Queen", "King"]

        var currentId = 22
        for suit in minorSuits {
            for rank in ranks {
                let name = "\(suit.rawValue) \(rank)"
                cards.append(TarotCard(id: currentId, name: name, suit: suit))
                currentId += 1
            }
        }

        return cards
    }()

    private init() { }
}

// MARK: - Tarot Result View Controller

final class TarotResultViewController: BaseViewController {

    private let cards: [TarotCard]
    private let hope: String

    // AI 앱 이동 버튼들을 담을 스택뷰
    private let aiButtonStackView = UIStackView().then {
        $0.axis = .horizontal
        $0.spacing = 15
        $0.distribution = .fillEqually
    }

    // 고민 텍스트 레이블
    private let hopeLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 18, weight: .semibold)
        $0.textColor = .white
        $0.textAlignment = .center
        $0.numberOfLines = 0
    }

    // 카드 리스트를 보여줄 컬렉션 뷰
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout().then {
            $0.scrollDirection = .horizontal // 일렬로 배치하기 위해 가로 스크롤 설정
            $0.minimumLineSpacing = 20
            $0.itemSize = CGSize(width: 150, height: 260) // 타로 카드 비율 고려
        }

        return UICollectionView(frame: .zero, collectionViewLayout: layout).then {
            $0.backgroundColor = .clear
            $0.showsHorizontalScrollIndicator = false
            $0.register(CardCollectionViewCell.self, forCellWithReuseIdentifier: CardCollectionViewCell.identifier)
            $0.delegate = self
            $0.dataSource = self
            // 카드들이 중앙에 오도록 여백 설정
            $0.contentInset = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 40)
        }
    }()

    init(cards: [TarotCard], hope: String) {
        self.cards = cards
        self.hope = hope
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupHierarchy()
        setupLayout()
        configureData()
        setupNavigationBar() // 네비게이션 설정 추가
    }

    private func setupNavigationBar() {
        // 1. 왼쪽 백버튼 숨기기 및 'X' 버튼 추가
        self.navigationItem.hidesBackButton = true
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        closeButton.tintColor = .white
        self.navigationItem.leftBarButtonItem = closeButton

        // 2. 오른쪽 복사 버튼 추가
        let copyButton = UIBarButtonItem(
            image: UIImage(systemName: "doc.on.doc"),
            style: .plain,
            target: self,
            action: #selector(copyButtonTapped)
        )
        copyButton.tintColor = .white
        self.navigationItem.rightBarButtonItem = copyButton
    }

    override func setupHierarchy() {
        super.setupHierarchy()
        view.addSubview(hopeLabel)
        view.addSubview(collectionView)
        view.addSubview(aiButtonStackView)
    }

    override func setupLayout() {
        super.setupLayout()

        hopeLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(40)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        collectionView.snp.makeConstraints {
            $0.top.equalTo(hopeLabel.snp.bottom).offset(50)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(300)
        }

        // AI 버튼 스택뷰 레이아웃
        aiButtonStackView.snp.makeConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
            $0.leading.trailing.equalToSuperview().inset(30)
            $0.height.equalTo(50)
        }
    }

    override func setupView() {
        super.setupView()
        setupAIButtons()
    }

    private func setupAIButtons() {
        let aiApps = [
            (name: "ChatGPT", scheme: "chatgpt://", color: UIColor(red: 0.44, green: 0.65, blue: 0.58, alpha: 1.0)),
            (name: "Gemini", scheme: "googlegemini://", color: .systemBlue),
            (name: "Claude", scheme: "claude://", color: UIColor(red: 0.82, green: 0.45, blue: 0.33, alpha: 1.0))
        ]

        aiApps.forEach { app in
            let button = UIButton().then {
                $0.setTitle(app.name, for: .normal)
                $0.backgroundColor = app.color
                $0.layer.cornerRadius = 10
                $0.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
                $0.tag = aiApps.firstIndex(where: { $0.name == app.name }) ?? 0
            }
            button.addTarget(self, action: #selector(aiButtonTapped(_:)), for: .touchUpInside)
            aiButtonStackView.addArrangedSubview(button)
        }
    }

    /// 복사할 텍스트를 생성하고 클립보드에 저장하는 공통 로직
    private func copyTarotResultToPasteboard() {
        let spreadPositions = ["과거", "현재", "미래"]

        let cardInfoList = cards.enumerated().map { (index, card) in
            let position = index < spreadPositions.count ? spreadPositions[index] : "카드 \(index + 1)"
            let direction = card.isReversed ? "(역방향)" : "(정방향)"
            return "• [\(position)] \(card.name) \(direction)"
        }.joined(separator: "\n")

        let copyText = """
            "\(hope)"라는 질문으로 점을 보려고 3 카드 스프레드를 사용해서 타로카드를 뽑았다.
            뽑은 카드는
            \(cardInfoList) 이다.
            이 카드를 어떻게 해석해야 할까? 사주와 함께 분석해줘.
            """

        UIPasteboard.general.string = copyText

        // 햅틱 피드백으로 복사됨을 알림
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    @objc private func aiButtonTapped(_ sender: UIButton) {
        let sYear = UserDefaults.standard.string(forKey: UDKey.sajuYear) ?? ""
        let sDay = UserDefaults.standard.string(forKey: UDKey.sajuDay) ?? ""
        let sHour = UserDefaults.standard.string(forKey: UDKey.sajuHour) ?? ""

        let hasSajuData = !sDay.isEmpty
        // 💡 월주(sMonth) 삭제
        let sajuText = hasSajuData ? "\n[나의 사주 정보]\n년주: \(sYear), 일주: \(sDay), 시주: \(sHour)\n" : ""

        let spreadPositions = ["과거", "현재", "미래"]
        let cardInfoList = cards.enumerated().map { (index, card) in
            let position = index < spreadPositions.count ? spreadPositions[index] : "카드 \(index + 1)"
            let direction = card.isReversed ? "(역방향)" : "(정방향)"
            return "• [\(position)] \(card.name) \(direction)"
        }.joined(separator: "\n")

        let analysisRequest = hasSajuData ? "타로 카드와 사주 정보를 결합해서 설명해줘." : "이 타로 카드들을 상세히 분석해줘."

        let copyText = """
            "\(hope)"라는 질문으로 점을 보려고 3 카드 스프레드를 사용해서 타로카드를 뽑았다.
            
            뽑은 카드는
            \(cardInfoList) 이다.
            \(sajuText)
            \(analysisRequest)
            """

        // 4. 앱 정보 및 스킴 설정
        let aiApps = ["ChatGPT", "Gemini", "Claude"]
        let schemes = ["chatgpt://", "googlegemini://", "claude://"]
        let appName = aiApps[sender.tag]
        let selectedScheme = schemes[sender.tag]

        // 5. 확인 Alert 띄우기
        let alert = UIAlertController(
            title: "\(appName)로 이동하시겠습니까?",
            message: "\n[복사될 질문 미리보기]\n\n\(copyText)",
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: "복사 후 이동", style: .default) { [weak self] _ in
            UIPasteboard.general.string = copyText
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            if let url = URL(string: selectedScheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                self?.view.makeToast("\(appName) 앱이 설치되어 있지 않습니다.")
            }
        }

        let cancelAction = UIAlertAction(title: "취소", style: .cancel)
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    @objc private func closeButtonTapped() {
        // 앱의 첫 화면(RootViewController)으로 이동
        self.navigationController?.popToRootViewController(animated: true)
    }

    @objc private func copyButtonTapped() {
        let spreadPositions = ["과거", "현재", "미래"]

        let cardInfoList = cards.enumerated().map { (index, card) in
            let position = index < spreadPositions.count ? spreadPositions[index] : "카드 \(index + 1)"
            let direction = card.isReversed ? "(역방향)" : "(정방향)"
            return "• [\(position)] \(card.name) \(direction)"
        }.joined(separator: "\n")

        let copyText = """
        "\(hope)"라는 질문으로 점을 보려고 3 카드 스프레드를 사용해서 타로카드를 뽑았다. 
        뽑은 카드는 
        \(cardInfoList) 이다. 
        이 카드를 어떻게 해석해야 할까? 사주와 함께 분석해줘.
        """

        UIPasteboard.general.string = copyText
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        let alert = UIAlertController(
            title: copyText,
            message: nil,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "글 복사하기", style: .default))
        self.present(alert, animated: true)
    }

    private func configureData() {
        hopeLabel.text = "“\(hope)”"
    }
}

extension TarotResultViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cards.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CardCollectionViewCell.identifier, for: indexPath)
                    as? CardCollectionViewCell else { return UICollectionViewCell() }

            let card = cards[indexPath.item]
            // 결과 화면이므로 뒤집힌 상태(isSelected: true)로 구성
            cell.configure(with: card, isSelected: true)

            return cell
        }
}

// MARK: - Saju

struct SajuResult {
    let year: String
    let month: String
    let day: String
    let hour: String
}

final class SajuManager {
    static let shared = SajuManager()
    private init() {}

    private let siduTable: [String: String] = [
        "갑": "갑", "기": "갑", "을": "병", "경": "병",
        "병": "무", "신": "무", "정": "경", "임": "경",
        "무": "임", "계": "임"
    ]

    private let skyStems = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"]

    func getAdjustedDate(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComp = calendar.dateComponents([.hour, .minute], from: time)
        components.hour = timeComp.hour
        components.minute = timeComp.minute

        guard let combinedDate = calendar.date(from: components) else { return date }
        let seoulTimeDate = combinedDate.addingTimeInterval(-30 * 60)

        let adjustedHour = calendar.component(.hour, from: seoulTimeDate)
        if adjustedHour >= 23 {
            return calendar.date(byAdding: .day, value: 1, to: seoulTimeDate) ?? seoulTimeDate
        }
        return seoulTimeDate
    }

    // 💡 월주 보정 로직을 제거하고 시주(hour)만 반환
    func calculateSiJu(apiItem: LunaItem, inputDate: Date) -> String {
        let iljin = apiItem.lunIljin
        let ilgan = String(iljin.prefix(1))

        guard let startGan = siduTable[ilgan] else { return "알 수 없음" }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: inputDate)
        let hourIdx = (hour + 1) / 2 % 12
        let branches = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"]

        let startGanIdx = skyStems.firstIndex(of: startGan) ?? 0
        let currentGan = skyStems[(startGanIdx + hourIdx) % 10]

        return "\(currentGan)\(branches[hourIdx])"
    }
}

enum UDKey {
    static let name = "user_name"
    static let gender = "user_gender"
    static let birthDate = "user_birth_date" // 날짜와 시간이 포함된 Date 객체
    // 계산된 사주 결과 저장용
    static let sajuYear = "saju_year"
    static let sajuMonth = "saju_month"
    static let sajuDay = "saju_day"
    static let sajuHour = "saju_hour"
}

// MARK: - ProfileViewController

final class ProfileViewController: BaseViewController {

    private let titleLabel = UILabel().then {
        $0.text = "사주 정보를 입력해주세요"
        $0.font = .systemFont(ofSize: 22, weight: .bold)
        $0.textColor = .white
    }

    private lazy var nameTextField = UITextField().then {
        $0.placeholder = "이름"
        $0.backgroundColor = .darkGray
        $0.textColor = .white
        $0.layer.cornerRadius = 8
        $0.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        $0.leftViewMode = .always
        $0.addTarget(self, action: #selector(viewTapped), for: .editingDidEndOnExit)
    }

    private lazy var genderSegment = UISegmentedControl(items: ["남성", "여성"]).then {
        $0.selectedSegmentIndex = 0
        $0.selectedSegmentTintColor = .systemPurple
        $0.addTarget(self, action: #selector(viewTapped), for: .valueChanged)
    }

    private lazy var datePicker = UIDatePicker().then {
        $0.datePickerMode = .date
        $0.preferredDatePickerStyle = .wheels
        $0.locale = Locale(identifier: "ko_KR")
        $0.addTarget(self, action: #selector(viewTapped), for: .valueChanged)
    }

    private lazy var timePicker = UIDatePicker().then {
        $0.datePickerMode = .time
        $0.preferredDatePickerStyle = .wheels
        $0.locale = Locale(identifier: "ko_KR")
        $0.addTarget(self, action: #selector(viewTapped), for: .valueChanged)
    }

    private lazy var saveButton = UIButton().then {
        $0.setTitle("정보 저장하기", for: .normal)
        $0.backgroundColor = .systemPurple
        $0.layer.cornerRadius = 12
        $0.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        $0.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .orange
        configureUIWithSavedData() // 💡 저장된 데이터로 UI 채우기
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
    }

    override func setupHierarchy() {
        [titleLabel, nameTextField, genderSegment, datePicker, timePicker, saveButton].forEach {
            view.addSubview($0)
        }
    }

    override func setupLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(30)
            $0.centerX.equalToSuperview()
        }

        nameTextField.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(30)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(50)
        }

        genderSegment.snp.makeConstraints {
            $0.top.equalTo(nameTextField.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
        }

        datePicker.snp.makeConstraints {
            $0.top.equalTo(genderSegment.snp.bottom).offset(20)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(120)
        }

        timePicker.snp.makeConstraints {
            $0.top.equalTo(datePicker.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(120)
        }

        saveButton.snp.makeConstraints {
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-30)
            $0.leading.trailing.equalToSuperview().inset(20)
            $0.height.equalTo(55)
        }
    }

    override func setupView() {
        super.setupView()
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        view.addGestureRecognizer(tap)
    }

    @objc private func viewTapped() {
        view.endEditing(true)
    }

    @objc private func saveButtonTapped() {
        guard let name = nameTextField.text, !name.isEmpty else { return }

        let inputDate = datePicker.date
        let inputTime = timePicker.date

        // 보정된 날짜 계산
        let adjustedDate = SajuManager.shared.getAdjustedDate(date: inputDate, time: inputTime)

        UserDefaults.standard.set(name, forKey: UDKey.name)
        UserDefaults.standard.set(genderSegment.selectedSegmentIndex, forKey: UDKey.gender)
        UserDefaults.standard.set(inputDate, forKey: UDKey.birthDate)
        UserDefaults.standard.set(inputTime, forKey: "user_birth_time")

        // 보정된 날짜를 전달하여 API 호출 및 시주 계산
        fetchSolar(date: adjustedDate, originalTime: inputTime)
    }

    private func configureUIWithSavedData() {
        nameTextField.text = UserDefaults.standard.string(forKey: UDKey.name)
        genderSegment.selectedSegmentIndex = UserDefaults.standard.integer(forKey: UDKey.gender)

        if let savedDate = UserDefaults.standard.object(forKey: UDKey.birthDate) as? Date {
            datePicker.date = savedDate

            // 저장된 원본 시간으로 복원 (오후 11시 30분이 정확히 표시됨)
            if let savedTime = UserDefaults.standard.object(forKey: "user_birth_time") as? Date {
                timePicker.date = savedTime
            }
        }
    }
    private func fetchSolar(date: Date, originalTime: Date) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        let dto = SolarRequestDTO(solarDay: day, solarMonth: month, solarYear: year)

        NetworkService.shared.fetch(.solarToLuna(requestDto: dto), type: SolarToLunaResponse.self) { [weak self] result in
            switch result {
            case .success(let answer):
                let item = answer.response.body.items.item

                // 💡 시주만 계산
                let fixedSiJu = SajuManager.shared.calculateSiJu(apiItem: item, inputDate: originalTime)

                // 💡 월주(sajuMonth) 저장 로직 삭제
                UserDefaults.standard.set(item.lunSecha, forKey: UDKey.sajuYear)
                UserDefaults.standard.set(item.lunIljin, forKey: UDKey.sajuDay)
                UserDefaults.standard.set(fixedSiJu, forKey: UDKey.sajuHour)

                NotificationCenter.default.post(name: NSNotification.Name("BirthDateChanged"), object: nil)

                DispatchQueue.main.async {
                    self?.navigationController?.popViewController(animated: true)
                }
            case .failure:
                self?.view.makeToast("사주 정보를 가져오지 못했습니다.")
            }
        }
    }

}
