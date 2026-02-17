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

final class MainViewController: BaseViewController {

    private let resultLabel = UILabel().then { lbl in
        lbl.textColor = .black
        lbl.numberOfLines = 0
        lbl.text = "생일을 입력하세요"
    }

    private let callButton = UIButton().then { btn in
        btn.setTitle("3카드 뽑기", for: .normal)
        btn.setTitleColor(.black, for: .normal)
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
            make.size.equalTo(200)
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
        print(#function)
        // 생일 정보 있으면 쓰고 아니면 바로 타로 카드
        fetchSolar()
        let selectVC = SelectCardViewController()
        navigationController?.pushViewController(selectVC, animated: true)
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
        copyTarotResultToPasteboard()

        let schemes = ["chatgpt://", "googlegemini://", "claude://"]
        let selectedScheme = schemes[sender.tag]

        if let url = URL(string: selectedScheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 앱이 설치되어 있지 않을 경우 알림
            let alert = UIAlertController(title: "알림", message: "\(sender.currentTitle ?? "해당") 앱이 설치되어 있지 않습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(alert, animated: true)
        }
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
    private init() { }
    
    func calculateSaju(date: Date, time: Date) -> SajuResult {
        let calendar = Calendar.current
        var calendarComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        calendarComponents.hour = timeComponents.hour
        calendarComponents.minute = timeComponents.minute

        guard var targetDate = calendar.date(from: calendarComponents) else {
            return SajuResult(year: "", month: "", day: "", hour: "")
        }

        // 1. 서울 시간 보정 (-30분 적용)
        targetDate = targetDate.addingTimeInterval(-30 * 60)

        // 2. 자시(23시~01시) 처리: 밤 11시가 넘으면 다음 날로 간주
        let adjustedHour = calendar.component(.hour, from: targetDate)
        if adjustedHour >= 23 {
            targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
        }

        // TODO: 만세력 라이브러리 또는 API 연동하여 간지 추출
        // 여기서는 구조 예시만 리턴합니다.
        return SajuResult(year: "갑진", month: "병인", day: "병인", hour: "무자")
    }
}
