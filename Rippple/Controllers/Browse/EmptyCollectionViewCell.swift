import UIKit

final class EmptyCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "empty"

    private let stack = UIStackView()
    let emojiLabel = UILabel()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let bodyLabel = UILabel()
    let actionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        contentView.backgroundColor = .clear

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16)
        ])

        emojiLabel.font = UIFont.systemFont(ofSize: 48)
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        bodyLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        actionButton.isHidden = true

        stack.addArrangedSubview(emojiLabel)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(bodyLabel)
        stack.addArrangedSubview(actionButton)
    }

    func configure(emoji: String, title: String, subtitle: String?, body: String, actionTitle: String? = nil, action: UIAction? = nil) {
        emojiLabel.text = emoji
        titleLabel.text = title
        subtitleLabel.text = subtitle
        bodyLabel.text = body

        if let actionTitle = actionTitle, let action = action {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
            actionButton.removeTarget(nil, action: nil, for: .allEvents)
            actionButton.addAction(action, for: .touchUpInside)
        } else {
            actionButton.isHidden = true
        }
    }
}
